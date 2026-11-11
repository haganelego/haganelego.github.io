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

#### 必要な secret（この repo の Settings → Secrets and variables → Actions）

- `ACHIEVEMENTS_READ_TOKEN`: Fine-grained personal access token。Resource owner は `kanaoka-lab`、対象リポジトリは `lab-achievements` のみ、権限は **Contents: Read** だけ。
  有効期限は最長 1 年なので、切れたら作り直して差し替える（切れると同期がエラーで止まるだけで、サイトは最後の状態のまま公開され続ける）。
- GitHub は 60 日間 repo に push が無いと `schedule` を自動停止する。その場合は Actions タブで「Sync achievements」を一度手動実行すると再開する。

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
