# CR-ALTM Navigation Improvement Report

Date: 2026-02-09

## Overview

warehouse_scheduled.launch.py で起動されるシミュレーション環境において、ロボットナビゲーションの品質向上のため以下4つの改善を実施した。

| Task | 概要 | 対象 |
|------|------|------|
| 1 | Global Costmap Inflation の拡大（壁際走行防止） | Nav2パラメータ |
| 2 | CR-ALTM マップカバレッジの拡大 | CR-ALTMパラメータ |
| 3 | ヒートマップ正規化パイプラインの修正 | CR-ALTMライブラリ |
| 4 | 予測コストマップのNav2統合 | ROS2ノード + Nav2 |

---

## Task 1: Global Costmap Inflation の拡大

### 問題

ロボットが壁ギリギリを走行するパスを選択していた。

### 原因

`inflation_radius: 0.55` ではコスト勾配の範囲が狭く、壁際でもコストが低いためプランナーが壁に近いパスを生成していた。

### 変更内容

**File**: `hunavsim/hunav_gazebo_wrapper/launch/pmb2_params/pmb2_nav_public_sim_gt.yaml` (lines 234-237)

```yaml
# Before
inflation_layer:
  plugin: "nav2_costmap_2d::InflationLayer"
  cost_scaling_factor: 3.0
  inflation_radius: 0.55

# After
inflation_layer:
  plugin: "nav2_costmap_2d::InflationLayer"
  cost_scaling_factor: 2.0
  inflation_radius: 1.2
```

### パラメータ選定理由

- **inflation_radius: 1.2m** - ロボット半径(0.275m)の約4倍。壁から十分な距離を取るパスを優先させる。
- **cost_scaling_factor: 2.0** - 値を下げることで減衰が緩やかになり、広い範囲にコスト勾配が適用される。高い値(3.0)では急激に減衰して壁から少し離れるとすぐコスト0になる。

---

## Task 2: CR-ALTM マップカバレッジの拡大

### 問題

CR-ALTMの観測範囲がマップ全体をカバーしておらず、一部のエリアで歩行者予測が生成されなかった。

### 原因

実際のマップ（PGMファイル: 435x415px, resolution=0.05）のサイズは 21.75m x 20.75m、origin=(-10.95, -10.45) であるのに対し、CR-ALTMは width=20.0m, height=15.0m で設定されていた。特にY方向に 5.75m の不足があった。

### 変更内容

#### File A: `cr_altm_navigation/config/cr_altm_navigation.yaml` (lines 38-39)

```yaml
# Before
map_width: 20.0
map_height: 15.0

# After
map_width: 22.0   # 21.75m + margin
map_height: 21.0   # 20.75m + margin
```

#### File B: `hunavsim/hunav_gazebo_wrapper/launch/warehouse_scheduled.launch.py` (lines 925-926)

```python
# Before
'map_width': 20.0,
'map_height': 15.0,

# After
'map_width': 22.0,
'map_height': 21.0,
```

### 注意点

launch file のインラインパラメータが YAML より優先されるため、**両方を更新する必要がある**。

---

## Task 3: ヒートマップ正規化の修正

### 問題

高観測エリア（人が頻繁に通る場所）のヒートマップ値が支配的になり、他のエリアの予測が相対的に消失していた。

### 原因

`predict_future()` 内の per-step 正規化が、各ステップの最大値で割るだけの単純な方式であり、観測密度の高いセルが常に最大値となるため他のセルの値が潰れていた。

### 変更内容

#### File: `cr_altm_navigation/cr_altm_navigation/CR-ALTM/src/memory/trajectory/prediction.py`

**変更1**: `predict_future()` (旧lines 225-229) - per-step正規化を削除

```python
# DELETED:
for step_idx in range(n_steps):
    step_max = result["heatmap"][:, :, step_idx].max()
    if step_max > 0:
        result["heatmap"][:, :, step_idx] /= step_max
```

**変更2**: `predict_future_combined()` - 新しい4段階パイプライン

```python
def predict_future_combined(
    ...,
    clip_max: float = 3.0,   # NEW parameter
) -> np.ndarray:
    result = predict_future(...)

    combined = np.zeros((height, width))
    for step_idx in range(n_steps):
        step_heatmap = result["heatmap"][:, :, step_idx].copy()
        # Step 1: Clip (prevents dense areas from dominating)
        step_heatmap = np.clip(step_heatmap, 0, clip_max)
        # Step 2: Normalize per step
        step_max = step_heatmap.max()
        if step_max > 0:
            step_heatmap = step_heatmap / step_max
        # Step 3: Combine with exponential decay
        decay = np.exp(-step_idx / n_steps)
        combined += decay * step_heatmap

    # Step 4: Final normalize
    if combined.max() > 0:
        combined = combined / combined.max()
    return combined
```

### パイプライン設計理由

| ステップ | 目的 |
|---------|------|
| Clip | 極端に高い値を切り落とし、密集エリアの支配を防止 |
| Per-step normalize | 各タイムステップを [0,1] に正規化し、時間による値差を均等化 |
| Decay combine | 近い未来ほど重要（exp decay）として重み付け合成 |
| Final normalize | 最終出力を [0,1] に正規化してOccupancyGrid変換に備える |

#### 関連パラメータ追加

- `cr_altm_navigation.yaml`: `prediction_clip_max: 3.0`
- `warehouse_scheduled.launch.py`: `'prediction_clip_max': 3.0`
- `cr_altm_navigation_node.py`: パラメータ宣言・取得・`predict_future_combined()` への受け渡し

---

## Task 4: 予測コストマップのNav2統合

### 目的

CR-ALTMが生成する歩行者予測ヒートマップをNav2のグローバルコストマップに反映し、ロボットが人の予測経路を避けるパスを計画するようにする。

### 最終構成

#### Nav2プラグイン設定

**File**: `pmb2_nav_public_sim_gt.yaml` (lines 198-238)

```yaml
global_costmap:
  global_costmap:
    ros__parameters:
      plugins: ["static_layer", "predicted_human_layer", "obstacle_layer", "inflation_layer"]

      predicted_human_layer:
        plugin: "nav2_costmap_2d::StaticLayer"
        map_topic: /predicted_human_costmap
        subscribe_to_updates: true
        map_subscribe_transient_local: false
        trinary_costmap: false
```

#### プラグイン順序の理由

```
static_layer → predicted_human_layer → obstacle_layer → inflation_layer
```

1. **static_layer**: ベースマップ（壁、障害物）を描画
2. **predicted_human_layer**: 予測コストを重畳
3. **obstacle_layer**: LiDARの動的障害物を上書き（予測より優先）
4. **inflation_layer**: 全レイヤーの結果に膨張コストを適用

### 実装の経緯と解決した問題

Task 4は4回のイテレーションを要した。Nav2 StaticLayer の内部動作に起因する問題が段階的に発覚した。

#### Iteration 1: 障害物が無視される

**問題**: predicted_human_layer を追加すると、障害物のグローバルコストが反映されなくなった。

**原因**: StaticLayer の `updateWithTrueOverwrite` が、予測マップの FREE_SPACE (0) セルで master costmap を上書きし、static_layer が描画した障害物コストが消えた。

**対策**: 予測のないセルを -1 (NO_INFORMATION) で埋め、`trinary_costmap: false` を設定。

#### Iteration 2: 障害物コストが予測で上書きされる

**問題**: ユーザーフィードバック：「static_layer, obstacle_layer の値に対して、予測したコストを重畳してほしい」

**対策**: `/map` トピックをsubscribeし、静的マップの障害物情報を予測出力にマージ。障害物セル=100、予測セル=[1-100]、非予測セル=-1 として発行。

#### Iteration 3: コストマップ全体が破壊される

**問題**: ナビゲーション開始・予測マップ発行開始時に inflation が完全に消失。壁際走行が再発。

**原因**: StaticLayer の `processMap()` が、受信した OccupancyGrid の解像度(0.5m)がmaster costmap の解像度(0.05m)と異なる場合に `layered_costmap_->resizeMap()` を呼び出し、**master costmap 全体を破壊**していた。

**対策**: 予測ヒートマップを `np.repeat()` でアップサンプリング（0.5m → 0.05m）し、`msg.info = sm.info` で静的マップと完全に同じメタデータで発行。

#### Iteration 4: 観測範囲外のコストが消失

**問題**: 予測の観測範囲外（マップ下部）のグローバルコストが消失。

**原因**: デフォルト値 -1 (NO_INFORMATION=255) が `updateWithTrueOverwrite` によって master costmap に書き込まれ、既存の障害物・自由空間データを上書きしていた。このNav2バージョンでは NO_INFORMATION セルもスキップされない。

**最終対策**: 出力の初期値を -1 ではなく**静的マップのコピー**にする。予測コストは「予測値がある AND 障害物でない」セルにのみオーバーレイ。

### 最終実装

**File**: `cr_altm_navigation/cr_altm_navigation/cr_altm_navigation_node.py`

主要な変更点:

1. `/map` トピックの購読（transient_local QoS）
2. `_map_callback()`: 静的マップを保存
3. `_build_obstacle_mask()`: 予測グリッド解像度での障害物マスク構築
4. `_publish_occupancy_grid()` の完全書き換え:

```python
def _publish_occupancy_grid(self, grid_data: OccupancyGridData) -> None:
    if self._static_map is None:
        return

    sm = self._static_map

    # 1. Start with a copy of the static map as base
    output = np.array(sm.data, dtype=np.int16).reshape(map_h, map_w)
    sm_data = output.copy()

    # 2. Get prediction and upsample to map resolution
    scale = max(1, int(round(self._grid_config.resolution / sm.info.resolution)))
    upsampled = np.repeat(np.repeat(pred_values, scale, axis=0), scale, axis=1)

    # 3. Overlay prediction costs on non-obstacle free cells only
    has_prediction = region > 0
    is_free = sm_data[:copy_h, :copy_w] < 65
    overlay_mask = has_prediction & is_free
    output[:copy_h, :copy_w][overlay_mask] = region[overlay_mask]

    # 4. Publish with same metadata as static map
    msg.info = sm.info
    msg.data = output.ravel().tolist()
```

### 設計上の重要な知見

| 項目 | 詳細 |
|------|------|
| **StaticLayer は THE map 用** | StaticLayer はメインマップ用に設計されており、オーバーレイ用途には向かない。受信マップの解像度/寸法が異なると master costmap を破壊する。 |
| **updateWithTrueOverwrite の動作** | このNav2バージョンでは NO_INFORMATION (-1/255) セルもスキップせず書き込む。全セルが上書き対象。 |
| **解決策: 完全マップを発行** | 静的マップをベースにコピーし、予測をオーバーレイした完全なマップを、静的マップと同一解像度・寸法で発行する。 |

---

## 変更ファイル一覧

| File | Tasks | 変更概要 |
|------|-------|---------|
| `pmb2_nav_public_sim_gt.yaml` | 1, 4 | inflation params変更、predicted_human_layer追加 |
| `cr_altm_navigation.yaml` | 2, 3 | map_width/height拡大、prediction_clip_max追加 |
| `warehouse_scheduled.launch.py` | 2, 3 | 同上（launch file側） |
| `prediction.py` | 3 | per-step正規化削除、clip-normalize-combine-normalize パイプライン |
| `cr_altm_navigation_node.py` | 3, 4 | clip_max param追加、/map購読、_publish_occupancy_grid完全書き換え |
| `nav2_costmap_override.yaml` | 4 | plugin順序・コメント更新（参考用設定ファイル） |

---

## パラメータ一覧（最終値）

### Nav2 Global Costmap

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| inflation_radius | 1.2 m | 壁からの膨張距離 |
| cost_scaling_factor | 2.0 | コスト減衰係数（低い=緩やか） |
| plugins | static, predicted_human, obstacle, inflation | レイヤー順序 |

### CR-ALTM Navigation Node

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| map_width | 22.0 m | 予測グリッド幅 |
| map_height | 21.0 m | 予測グリッド高さ |
| map_origin_x | -10.95 m | マップ原点X |
| map_origin_y | -10.45 m | マップ原点Y |
| output_resolution | 0.5 m | 内部予測解像度（発行時は0.05mにアップサンプル） |
| prediction_clip_max | 3.0 | ヒートマップクリップ閾値 |
| prediction_rate | 2.0 Hz | 予測発行頻度 |

### predicted_human_layer (Nav2 StaticLayer)

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| map_topic | /predicted_human_costmap | 購読トピック |
| subscribe_to_updates | true | 更新購読 |
| map_subscribe_transient_local | false | 非latched（定期更新） |
| trinary_costmap | false | 段階的コスト値を保持 |

---

## 検証方法

1. `colcon build` でビルドエラーなし確認
2. シミュレーション起動後、`ros2 topic echo /predicted_human_costmap --once` でOccupancyGrid出力確認
3. RViz で global_costmap を可視化し以下を確認:
   - 壁からの十分な距離のパス選択
   - 予測コストマップの反映
   - 観測範囲外のコストマップデータ保持
4. ロボットが壁から離れたルート かつ 人の予測経路を避けるルートを選択
