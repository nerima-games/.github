# 適合チェックリスト

`src/` 再構成後の目標状態（[PACKAGE_STANDARD.md](PACKAGE_STANDARD.md)）、
`docs/` の必須ページ（[DOCS_STANDARD.md](DOCS_STANDARD.md)）、
カバレッジゲート（[TEST_STANDARD.md](TEST_STANDARD.md) §3-4）を
1リポジトリずつ機械的に確認するための一覧です。
判定は `scripts/check-conformance.sh` が行います。

## 実行方法

```console
$ ./scripts/check-conformance.sh ~/ghq/github.com/nerima-games          # 全16リポジトリ
$ ./scripts/check-conformance.sh ~/ghq/github.com/nerima-games mc-kernel # 1リポジトリだけ
$ ./scripts/check-conformance.sh ~/ghq/github.com/nerima-games mc-kernel mx-ui # 複数指定
```

引数を省略すると `mc-audio` `mc-compose` `mc-dev-meta` `mc-kernel` `mc-meshing` `mc-noise`
`mc-physics` `mc-playground-kit` `mc-render` `mc-save` `mc-sim` `mc-worldgen` `mx-gameplay`
`mx-multiplayer` `mx-redstone` `mx-ui` の16リポジトリ全部を対象にします。
非スキップ項目が1つでも不適合なら終了ステータス1を返すので、CIのゲートにそのまま使えます。
git に書き込むコマンドは実行しません（読み取り専用）。

## 判定項目

各リポジトリについて以下の8カテゴリを判定します。

### 1. git

- `main` ブランチ上にいる
- 作業ツリーがクリーン（`git status --porcelain` が空）

### 2. ディレクトリ形状

- `src/index.ts` が存在する
- `src/domain/` が存在する
- `apps/` を持つ場合、それは `src/` の中ではなくリポジトリ直下にある（`src/apps/` は存在しない）
- `test/` `scripts/` `docs/` がリポジトリ直下に存在する

### 3. 廃止物の不在

移行後に存在してはならないファイル群です。

- `api-lock.md`（リポジトリ直下）
- `scripts/api-lock.ts`
- `scripts/check-dependency-whitelist.ts`

### 4. `package.json`

- `main` が `./src/index.ts` を指す
- `exports["."]` が `./src/index.ts` を指す
- `api:check` / `api:update` / `check:deps` のいずれのスクリプトも残っていない

### 5. `docs/` の必須ページ

`README.md` `architecture.md` `responsibility.md` `public-api.md` `testing.md`
`versioning.md` `design-notes.md` `porting.md` の8ページを確認します。

**名指しの例外**（[DOCS_STANDARD.md](DOCS_STANDARD.md) 参照。理由を隠さず列挙します):

| リポジトリ | 例外 | 理由 |
|---|---|---|
| `mc-kernel` | `porting.md` のみスキップ | 参照実装の複数箇所から語彙を合成しており、単一モジュールの移植ではないため（DOCS_STANDARD.md §2-2） |
| `mc-dev-meta` | `design-notes.md` と `porting.md` をスキップ | 4層依存グラフの外にある開発ツールリポジトリで、代わりに `workflow.md` / `manifest.md` / `step2-status.md` という独自ページ集合を持つため（DOCS_STANDARD.md §2-3） |

どちらも「移行の遅れ」ではなく恒久的な適用除外です。上記2リポジトリ以外でこれらのページが
欠けている場合は、通常どおり不適合として赤く報告されます。

### 6. CI (`ci.yaml`)

- `.github/workflows/ci.yaml` に `permissions:` ブロックがある
- `uses:` 行がすべて40文字のコミットSHAにピン留めされている（タグのみの参照は不適合とし、
  該当アクション名を表示する）。ローカルの複合アクション（`./.github/...`）はピン留めの対象外

### 7. Dependabot

- `.github/dependabot.yml` が存在する

### 8. カバレッジゲート

`vitest.config.ts` の `test.coverage.thresholds` が `branches` / `functions` / `lines` /
`statements` の4指標について99%以上のしきい値で**有効化**されていることを確認します
（コメントアウトされたブロックは無効とみなします）。

**名指しの例外**（[TEST_STANDARD.md](TEST_STANDARD.md) §4 参照）:

| リポジトリ | 理由 |
|---|---|
| `mc-audio` | 既知の移行途中、`MIGRATION_RUNBOOK.md` で追跡 |
| `mc-compose` | 既知の移行途中、`MIGRATION_RUNBOOK.md` で追跡 |
| `mc-playground-kit` | 既知の移行途中、`MIGRATION_RUNBOOK.md` で追跡 |

この3リポジトリ以外で `thresholds` が無効(コメントアウトされたまま)の場合は、
TEST_STANDARD.md §4 の方針どおり例外扱いせず不適合として報告します
（本書作成時点では `mc-dev-meta` `mc-meshing` `mc-noise` `mc-physics` `mc-render` `mc-save`
`mc-sim` `mc-worldgen` `mx-multiplayer` がこれに該当し、素の不適合として赤くなります)。

> 本書作成時点で `nerima-games/.github` に `MIGRATION_RUNBOOK.md` はまだ存在しません。
> スキップ理由の文言は `TEST_STANDARD.md` §4 の記述に基づく先行表記であり、
> 当該ファイルが実際に作成され次第そこが参照先になります。

## 出発点（2026-08-01 時点）

`scripts/check-conformance.sh` を実際に16リポジトリへ実行した結果、
**404項目中203項目が通過**しました（12項目は上記の名指し例外でスキップ）。
`src/` への移行はまだどのリポジトリでも行われていないため、この結果は想定内です。
`PACKAGE_STANDARD.md` 冒頭が明記するとおり「現時点でこの形になっているリポジトリはまだ存在しない」
状態を、このスクリプトは正直に赤で反映しているだけです。

| リポジトリ | 通過 | 不適合 | スキップ | 合計 |
|---|---|---|---|---|
| `mc-audio` | 13 | 12 | 1 | 26 |
| `mc-compose` | 13 | 12 | 1 | 26 |
| `mc-dev-meta` | 10 | 13 | 3 | 26 |
| `mc-kernel` | 12 | 12 | 2 | 26 |
| `mc-meshing` | 12 | 13 | 1 | 26 |
| `mc-noise` | 12 | 13 | 1 | 26 |
| `mc-physics` | 12 | 13 | 1 | 26 |
| `mc-playground-kit` | 13 | 12 | 1 | 26 |
| `mc-render` | 13 | 13 | 0 | 26 |
| `mc-save` | 12 | 13 | 1 | 26 |
| `mc-sim` | 13 | 13 | 0 | 26 |
| `mc-worldgen` | 13 | 13 | 0 | 26 |
| `mx-gameplay` | 14 | 12 | 0 | 26 |
| `mx-multiplayer` | 13 | 13 | 0 | 26 |
| `mx-redstone` | 14 | 12 | 0 | 26 |
| `mx-ui` | 14 | 12 | 0 | 26 |

観測できた主な不適合パターン（全16リポジトリで概ね共通):

- **git**: 全リポジトリが `main` 以外の作業ブランチ上（例: `feat/modernize-toolchain`）で、
  かつ作業ツリーに未コミットの変更がある。移行作業そのものが進行中であることの反映であり、
  進捗の指標として差し引いて読む。
- **ディレクトリ形状 / package.json**: `src/index.ts` `src/domain/` がまだ存在せず、
  `index.ts` `domain/` がリポジトリ直下に残っている。`package.json` の `main` / `exports["."]`
  も `./index.ts` を指したまま。これは `PACKAGE_STANDARD.md` が「目標状態」と明記する移行前状態そのもの。
- **廃止物の不在**: `api-lock.md` / `scripts/api-lock.ts` / `scripts/check-dependency-whitelist.ts`
  は16リポジトリ全部にまだ残っている。
- **CI SHA-pin**: 全リポジトリで `pnpm/action-setup` のみコミットSHAにピン留めされており、
  `actions/checkout` `actions/setup-node` `actions/upload-artifact` はタグ参照のまま
  （`permissions:` ブロック自体はどのリポジトリも既にある）。
- **Dependabot**: `.github/dependabot.yml` はどのリポジトリにも存在しない。
- **カバレッジゲート**: 名指し例外の3リポジトリ以外にも、`thresholds` がコメントアウトされたままの
  リポジトリが複数ある（`mc-kernel` `mx-gameplay` `mx-redstone` `mx-ui` の4つは既に有効化・通過済み）。

この数値は再実行すれば更新されるので、移行の進捗指標として使えます。
