# haganelego.github.io

Daiju Kanaoka の個人ページ（[Hugo Blox](https://hugoblox.com/) Academic CV テンプレート、英語 / 日本語）。
GitHub Pages に `main` ブランチから自動デプロイされる（`.github/workflows/deploy.yml`）。

## 何が自動で、何が手動か

| 内容 | 更新方法 | 置き場所 |
|---|---|---|
| 論文・受賞・特許 | **自動**。業績データ repo [kanaoka-lab/lab-achievements](https://github.com/kanaoka-lab/lab-achievements) から毎日生成してコミット | `data/achievements/*.yaml`、`content/publications/<slug>/`、`content/ja/publications/<slug>/`（**手で編集しない**） |
| 自己紹介・所属・経歴・学歴・リンク | 手動で編集して `main` に push | `data/authors/me.yaml`、`data/authors/me_ja.yaml` |
| 業績の見せ方（節の分け方、詳細ページを作る種別、除外、URL） | 手動 | `achievements.yaml` |
| 見出しの文言 | 手動 | `i18n/en.yaml`、`i18n/ja.yaml` |

### 自動同期の流れ（`.github/workflows/sync-achievements.yml`）

毎日 03:00 JST（または Actions タブから手動実行）に、

1. `kanaoka-lab/lab-achievements` を読み取り専用トークンで checkout
2. `python -m tools.export_hugoblox --root _achievements --site .` でサイト用ファイルを生成
3. 内部フィールドが混ざっていないか確認し、差分があれば Hugo でビルドできることを確かめてから `main` にコミット
4. `deploy.yml` を起動して公開

lab-achievements 側の CI にも、`main` への push 後にこのワークフローを起動する任意ステップがある（secret `WEBSITE_DISPATCH_TOKEN`）。

#### 必要な secret: `ACHIEVEMENTS_READ_TOKEN`

lab-achievements（private）を CI から読むための Fine-grained personal access token。**有効期限は最長 1 年**で、切れると「Sync achievements」が checkout の段階で失敗し（`Actions` タブに赤く残る）、サイトは最後に同期した状態のまま公開され続ける。
期限が来たら以下の手順で作り直して差し替える（トークンの値以外は秘密情報ではない）。

1. GitHub 右上のアイコン → **Settings** → 左下 **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
2. 次のとおり設定する
   - Token name: `haganelego.github.io achievements sync`（任意）
   - Expiration: 最長の 1 year（カレンダーに更新予定を入れておく）
   - Resource owner: **kanaoka-lab**（個人アカウントではなく組織を選ぶ）
   - Repository access: **Only select repositories** → `kanaoka-lab/lab-achievements`
   - Permissions → Repository permissions → **Contents: Read-only**。他はすべて No access のまま（Metadata は自動で Read-only になる）
3. **Generate token** を押し、表示された値をコピーする（この画面を閉じると二度と見られない）
4. この repo の **Settings → Secrets and variables → Actions** → `ACHIEVEMENTS_READ_TOKEN` の鉛筆アイコン（初回は New repository secret）→ 値を貼り付けて保存
5. **Actions** タブ → **Sync achievements** → **Run workflow** → `main` で一度実行し、緑で終わることを確認する（差分が無ければ "Site already up to date." で終わる）
6. 古いトークンは Developer settings の一覧から削除してよい

組織側で fine-grained token の利用が「要承認」になっている場合、手順 3 の直後に kanaoka-lab の **Settings → Personal access tokens → Pending requests** で承認が必要になる。

#### その他の運用メモ

- GitHub は 60 日間 repo に push が無いと `schedule` を自動停止する。その場合は Actions タブで「Sync achievements」を一度手動実行すると再開する。
- lab-achievements 側から即時に同期を起動したい場合は、この repo に **Actions: Read and write** の fine-grained token（手順は上と同じで対象リポジトリをこの repo にする）を作り、lab-achievements の secret `WEBSITE_DISPATCH_TOKEN` に登録する。無くても毎日同期される。

### 業績の見せ方を変える（`achievements.yaml`）

```yaml
sections:                     # /publications の節と、lab-achievements の venue_type の対応（表示順）
  journal: [international_journal, domestic_journal]
  international: [international_conference]
  misc: [domestic_conference, workshop]
  preprint: [arxiv]
detail_pages: [journal, international]   # 詳細ページ（index.md + cite.bib）を作る節。トップの Recent Publications はここから最新 5 件
english_page_excludes_japanese: true     # 英語ページでは日本語で書かれた業績を出さない
exclude: []                              # 隠したい record ID
slugs: {pub-000015: kanaoka2023bmvc}     # record ID → URL の上書き
```

- どの節にも書かれていない venue_type（学位論文 `thesis` など）はサイトに出ない。
- 節を増やしたら `i18n/*.yaml` に `pub_<節名>` の見出しを足す。
- トップの表示件数は `content/_index.md` / `content/ja/_index.md` の collection block の `count`。

## ローカルで確認する

業績データは別 repo なので、隣に clone して `pnpm sync` で生成する（Python の依存は [uv](https://docs.astral.sh/uv/) が解決する）。

```bash
# 初回のみ
git clone git@github.com:kanaoka-lab/lab-achievements.git ../lab-achievements
pnpm install

# 業績を再生成してプレビュー
pnpm sync            # ../lab-achievements から data/achievements と content/**/publications を生成
pnpm dev             # http://localhost:1313/en/  /ja/  /en/publications/  /ja/publications/
pnpm sync:check      # 生成物が最新か確認（差分があれば exit 1、書き込みはしない）
```

clone の場所が違う場合は `ACHIEVEMENTS_ROOT=/path/to/lab-achievements pnpm sync`。
ローカルで生成した差分はコミットしなくてよい（CI が同じものを生成する）。

## 構成メモ

- Hugo のバージョンは `hugoblox.yaml` の `build.hugo_version`。テーマモジュールは `_vendor/` に vendoring 済み。
- 既定言語は日本語（`/` → `/ja/`）。英語は `/en/`。言語ごとの content ディレクトリは `config/_default/module.yaml` の mounts で指定（`content` → en、`content/ja` → ja）。
- `layouts/publications/list.html` が業績一覧ページ（論文・受賞・特許）で、`site.Data.achievements.*` だけを読む。トップの「Recent Publications」はテーマの collection block（`content/_index.md`）。メニューの「Awards」は業績ページの受賞節へのリンク。
- `layouts/_partials/achievements/visible.html` が言語による除外を一か所で行う。
