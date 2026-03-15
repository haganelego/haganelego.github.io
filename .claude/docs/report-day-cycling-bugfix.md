# Day Cycling System Bug Fix Report

**Date**: 2026-02-10
**Scope**: ExperimentOrchestrator service call failures + agent respawn issues

---

## 1. Problem Statement

ExperimentOrchestrator による日の切り替え処理で以下の2つのバグが発生していた。

### Bug 1: Service Call Failures
Day transition の Phase 1 (PAUSE) 〜 Phase 6 (RESTART) で、複数のサービスコールがタイムアウトまたは失敗。

| Service | Symptom |
|---------|---------|
| `/cr_altm_navigation_node/pause` | call failed or timed out (10s) |
| `/cr_altm_navigation_node/save_memory` | call failed or timed out (10s) |
| `/cr_altm_navigation_node/clear_observations` | call failed or timed out (10s) |
| `/set_entity_state` | not available (service doesn't exist) |
| `/global_costmap/clear_entirely_global_costmap` | not available |
| `/local_costmap/clear_entirely_local_costmap` | not available |

### Bug 2: Agents Teleporting to Center
スケジュールリロード時に、人間エージェント全員がワールド中心 (0, 0) にテレポートし、床にめり込む。

---

## 2. Root Cause Analysis

### Bug 1a: Service Call Deadlock

**File**: `hunav_evaluator/experiment_orchestrator.py:349`

```python
# BEFORE (deadlock)
rclpy.spin_until_future_complete(self, future, timeout_sec=timeout)
```

`ExperimentOrchestrator` は `MultiThreadedExecutor(num_threads=4)` で動作している。
`_call_service_sync` はタイマーコールバック (`_timer_cb_group`) 内から呼ばれるが、
`rclpy.spin_until_future_complete()` は同一ノードを再度スピンしようとするため、
エグゼキューターとの競合でデッドロックが発生する。

サービスレスポンスは `_service_cb_group` (別の MutuallyExclusiveCallbackGroup) で処理される
はずだが、`spin_until_future_complete` がブロックするため他スレッドがレスポンスを処理できない。

### Bug 1b: Missing Gazebo State Plugin

**File**: `hunav_gazebo_wrapper/launch/warehouse_scheduled.launch.py:236-244`

```python
gzserver_cmd = [
    ...
    '-s ', 'libgazebo_ros_init.so',
    '-s ', 'libgazebo_ros_factory.so',
    # libgazebo_ros_state.so が無い → /set_entity_state サービスが立ち上がらない
]
```

`libgazebo_ros_state.so` プラグインが gzserver に読み込まれていないため、
`/set_entity_state` と `/get_entity_state` サービスが存在しない。

### Bug 2a: Multiple Spurious Schedule Transitions

**File**: `hunav_agent_manager/src/sequence_controller_node.cpp:299-305`

```cpp
// BEFORE (multiple transitions)
first_update_ = true;   // → 次の simulation_time で即座に再トランジション
last_day_ = 0;           // → Day 0 → Day 1 の遷移検出
last_sequence_ = 0;      // → Sequence 0 → Sequence 1 の遷移検出
```

`reloadScheduleService` で `first_update_ = true` に設定すると、
`simulationTimeCallback` が以下のように多重にスケジュール遷移を検出する:

```
1. reloadScheduleService: publishScheduleInfo(Day 1, Seq 1) → agent_manager に送信
2. simulationTimeCallback: 旧時刻 Day 2 → transition検出 → publishScheduleInfo(Day 2, Seq 1)
3. time reset → simulationTimeCallback: Day 1 → transition検出 → publishScheduleInfo(Day 1, Seq 1)
```

`hunav_agent_manager` が短時間に3回のスケジュール更新を受け取り、
各更新で `clearAgentGoals` → `addAgentGoal` が実行される。
この間にSFM計算が走ると、ゴールが空の状態でエージェントが処理される。

### Bug 2b: No Agent Respawn on Day Transition

RESPAWN フェーズでロボットのテレポートは実装されていたが、
人間エージェントのテレポートが未実装だった。
Day 2 のスケジュールでは `init_pose` が Day 1 と異なるため
(例: worker0 が y: 6.75 → y: -6.75)、
Gazebo 上の物理位置と新スケジュールのゴール開始点が大きく乖離する。

---

## 3. Fixes Applied

### Fix 1: Replace `spin_until_future_complete` with Polling Loop

**File**: `hunav_evaluator/experiment_orchestrator.py` (L398-427)

```python
# AFTER (polling)
future = client.call_async(request)
start = _time.monotonic()
while not future.done():
    if _time.monotonic() - start > timeout:
        break
    _time.sleep(0.01)
```

Wall-clock ベースのポーリングに変更。MultiThreadedExecutor の別スレッドが
サービスレスポンスコールバックを処理するため、デッドロックが解消される。

### Fix 2: Add `libgazebo_ros_state.so` to gzserver

**File**: `hunav_gazebo_wrapper/launch/warehouse_scheduled.launch.py` (L243)

```python
'-s ', 'libgazebo_ros_init.so',
'-s ', 'libgazebo_ros_factory.so',
'-s ', 'libgazebo_ros_state.so',    # Added
```

### Fix 3: Prevent Multiple Schedule Transitions on Reload

**File**: `hunav_agent_manager/src/sequence_controller_node.cpp` (L299-308)

```cpp
// AFTER (stable state)
publishScheduleInfo(1, 1);
first_update_ = false;    // NOT true
last_day_ = 1;            // Match published state
last_sequence_ = 1;       // Match published state
```

リロード後の状態を「Day 1, Seq 1 を既に publish 済み」にセットすることで、
`simulationTimeCallback` が同じ Day/Sequence を受け取っても再トランジションしない。

### Fix 4: Add Human Agent Respawn

**File**: `hunav_evaluator/experiment_orchestrator.py` (L323-374)

新メソッド3つを追加:

| Method | Purpose |
|--------|---------|
| `_get_agent_init_poses(schedule_path)` | Schedule YAML から `init_pose` を読み取り |
| `_respawn_agents(schedule_path)` | 全エージェントをテレポート |
| `_teleport_entity(name, x, y, z, yaw)` | `/set_entity_state` で単一エンティティ移動 |

Phase 5 (RESPAWN) でロボットに加えて人間エージェントもテレポートする。

---

## 4. Files Changed

| File | Type | Change |
|------|------|--------|
| `hunav_evaluator/experiment_orchestrator.py` | Python | Service call fix + agent respawn |
| `hunav_gazebo_wrapper/launch/warehouse_scheduled.launch.py` | Launch | Add state plugin |
| `hunav_agent_manager/src/sequence_controller_node.cpp` | C++ | Fix reload transition state |

---

## 5. Build Requirements

```bash
# C++ パッケージのリビルドが必要
cd ~/usr/github/hunavsim_craltm
colcon build --packages-select hunav_agent_manager

# Python パッケージ (install ディレクトリ使用時)
colcon build --packages-select hunav_evaluator hunav_gazebo_wrapper
```

---

## 6. Expected Behavior After Fix

### Day Transition Flow (正常系)

```
Phase 1: PAUSE
  ├─ /pause_physics                              ✓ (polling, no deadlock)
  ├─ /robot_goal_scheduler/pause                 ✓
  ├─ /human_detector/pause                       ✓
  └─ /cr_altm_navigation_node/pause              ✓ (was: deadlock timeout)

Phase 2: EXPORT
  ├─ /cr_altm_navigation_node/save_memory        ✓ (was: deadlock timeout)
  ├─ /navigation_cost_metrics/export_metrics     ✓
  └─ /proximity_metrics/export_metrics           ✓

Phase 3: RESET
  ├─ metrics reset                               ✓
  ├─ /cr_altm_navigation_node/clear_observations ✓ (was: deadlock timeout)
  ├─ /robot_goal_scheduler/reset                 ✓
  └─ costmap clear                               ✓ (optional, short timeout)

Phase 4: RELOAD
  └─ /reload_schedule → Day 1, Seq 1 published   ✓ (was: triple publish)

Phase 5: RESPAWN
  ├─ Robot teleport via /set_entity_state         ✓ (was: service not available)
  └─ Agent teleport via /set_entity_state         ✓ (NEW: agents to init_pose)

Phase 6: RESTART
  ├─ /reset_time                                 ✓
  ├─ Resume all nodes                            ✓
  └─ /unpause_physics                            ✓
```

### Costmap Services

`/global_costmap/clear_entirely_global_costmap` と `/local_costmap/clear_entirely_local_costmap`
は Nav2 の設定に依存。現在の launch 構成では timeout=2.0s で skip される設計（optional）。
Nav2 が起動していない、またはサービス名が異なる可能性あり。
Nav2 の costmap ノードのサービス名を確認する必要がある（今回の修正範囲外）。

---

## 7. Remaining Considerations

1. **Costmap clear services**: Nav2 の costmap サービス名が現在の設定と一致しているか要確認
2. **Agent name in Gazebo**: `/set_entity_state` で使うエンティティ名 (e.g., "worker0") が
   Gazebo 内のモデル名と一致している必要がある。hunav_gazebo_world_generator が生成する
   モデル名を確認すること
3. **MutuallyExclusiveCallbackGroup**: 全サービスクライアントが同一の
   `_service_cb_group` にあるため、同時に1つのサービスコールしか処理されない。
   現在は逐次呼び出しなので問題ないが、並列化する場合は別グループが必要
