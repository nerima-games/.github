# 適合チェックリスト

`src/` 再構成後・Wave 0 の dist 公開形への移行後の目標状態（[PACKAGE_STANDARD.md](PACKAGE_STANDARD.md)）、
`docs/` の必須ページ（[DOCS_STANDARD.md](DOCS_STANDARD.md)）、
カバレッジゲート（[TEST_STANDARD.md](TEST_STANDARD.md) §3）、
リリースワークフロー（[RELEASE_STANDARD.md](RELEASE_STANDARD.md) §3）を
1リポジトリずつ機械的に確認するための一覧です。
判定は `scripts/check-conformance.sh` が行います（`jq` が必須。`main` / `exports["."]`
がネストした JSON になったため、行指向の `grep` では確実に判定できません）。

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

各リポジトリについて以下の9カテゴリを判定します。

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

### 4. `package.json`（dist 公開形。PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」）

- `main` が `./dist/index.js` を指す
- `exports["."]` が `{ types: "./dist/index.d.ts", import: "./dist/index.js", ... }` を指す
- `api:check` / `api:update` / `check:deps` のいずれのスクリプトも残っていない

**名指しの例外**（[PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」](PACKAGE_STANDARD.md) 参照）:

| リポジトリ | 例外 | 理由 |
|---|---|---|
| `mc-compose` | `main` / `exports["."]` は `./dist/index.js` ではなく `./src/index.ts` のまま | compose を import する下流リポジトリが存在せず、配布物は `vite build` が生成する web バンドル。dist 形へ寄せる理由がないため、他リポジトリと同じ強さの判定を compose 用の別条件として明示的にコードへ書く（`check-dependency-whitelist.ts` 時代のような「全リポジトリ一律」の緩和はしない） |

この例外以外のリポジトリで `main` / `exports["."]` が `./dist/index.js` 系を指していない場合は、
通常どおり不適合として赤く報告されます。

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
- `permissions:` に `packages: read` が含まれる（PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」。
  `@nerima-games/*` の兄弟パッケージを GitHub Packages から `pnpm install` するために必要）。
  この判定は16リポジトリ一律で行い、**`mc-kernel` のみ想定内の不適合になります**
  — `workflow-templates/ci.yml` は「mc-kernel origin/main の ci.yaml を土台に他15リポジトリへ
  足す差分」として設計されたテンプレートであって、kernel 自身の ci.yaml への追加ではないため
- `uses:` 行がすべて40文字のコミットSHAにピン留めされている（タグのみの参照は不適合とし、
  該当アクション名を表示する）。ローカルの複合アクション（`./.github/...`）はピン留めの対象外

### 7. Dependabot

- `.github/dependabot.yml` が存在する

### 8. リリースワークフロー（RELEASE_STANDARD.md §3、`workflow-templates/release.yml`）

- `.github/workflows/release.yaml` が存在する

**名指しの例外**:

| リポジトリ | 例外 | 理由 |
|---|---|---|
| `mc-dev-meta` | スキップ | `"private": true` の非公開 pnpm workspace バインダーで、RELEASE_STANDARD.md §0 が明示的にスコープ外としている（公開しないため release workflow を持ちようがない） |

`mc-kernel` は既にこの形の `release.yaml`（detect → publish → tag）を持ち、
`workflow-templates/release.yml` はこれをそのままコピーしたものなので、kernel はこの項目では
緑になります。

### 9. カバレッジゲート

`vitest.config.ts` の `test.coverage.thresholds` が `branches` / `functions` / `lines` /
`statements` の4指標について**100%**のしきい値で**有効化**されていることを確認します
（コメントアウトされたブロックは無効とみなします）。TEST_STANDARD.md §3 の閾値が
2026-08-01 の 99% から 100% に引き上げられたことに伴う変更です。

**名指しの例外は現在ありません。** `scripts/check-conformance.sh` の `COVERAGE_EXEMPT` は空リストです。`mc-compose` はカバレッジのしきい値に届いていないため、例外にせず不適合として扱います。今後、名指しの例外を設ける場合は、`COVERAGE_EXEMPT` と `coverage_exempt_reason()` を使います。

## 出発点（2026-08-30 時点、Wave 0 適用前）

`scripts/check-conformance.sh` を、[mc-dev-meta の P0-6 同期スナップショット](../mc-dev-meta)
（`mc-dev-meta` 自体は同期対象に含まれておらず「not found」で報告される）に対して実際に実行した
結果、420件の判定中360件が通過し、54件が不適合、6件がスキップでした。
Wave 0 のロールアウトはこの `.github` リポジトリの標準文書更新が最初の一歩であり、
各リポジトリ側への適用（`package.json` の dist 化、CI への `packages: read` 追加、
`release.yaml` の設置、カバレッジ100%化)はこの時点でまだ完了していません。

| リポジトリ | 通過 | 不適合 | スキップ | 合計 |
|---|---|---|---|---|
| `mc-audio` | 24 | 4 | 0 | 28 |
| `mc-compose` | 25 | 3 | 0 | 28 |
| `mc-dev-meta` | (repos/ 配下に同期コピーが無く "not found" として報告される) | | | |
| `mc-kernel` | 24 | 2 | 2 | 28 |
| `mc-meshing` | 25 | 2 | 1 | 28 |
| `mc-noise` | 25 | 2 | 1 | 28 |
| `mc-physics` | 25 | 2 | 1 | 28 |
| `mc-playground-kit` | 25 | 3 | 0 | 28 |
| `mc-render` | 26 | 2 | 0 | 28 |
| `mc-save` | 25 | 2 | 1 | 28 |
| `mc-sim` | 24 | 4 | 0 | 28 |
| `mc-worldgen` | 26 | 2 | 0 | 28 |
| `mx-gameplay` | 19 | 9 | 0 | 28 |
| `mx-multiplayer` | 22 | 6 | 0 | 28 |
| `mx-redstone` | 23 | 5 | 0 | 28 |
| `mx-ui` | 22 | 6 | 0 | 28 |

観測できた主な不適合パターン(全リポジトリ共通の傾向のみを述べており、上表の不適合数の
内訳を1件ずつ足し合わせたものではありません。個別リポジトリの完全な内訳は
`bash scripts/check-conformance.sh <repos-dir> <repo>` を1リポジトリ指定で再実行して
確認してください):

- **git**: 同期スナップショットはどのリポジトリも detached HEAD（`main` ではない）で作られており、
  「branch is main」チェックは全リポジトリで赤くなる。これは同期の作り方に起因する既知の
  偽陽性で、実際の各リポジトリの `main` ブランチの状態を表さない。作業ツリーは全リポジトリで
  クリーン。
- **`mc-kernel` の想定内の不適合はちょうど2件**: 上記 git の偽陽性1件と、
  `ci.yaml` の `packages: read` 未設置1件（§6 参照。kernel の設計上、追加不要と判断できる）。
  それ以外の全項目(dist 公開形、release.yaml、カバレッジ100%など)は既に緑。
- **package.json の dist 化**: `mc-compose` `mx-gameplay` `mx-multiplayer` `mx-redstone`
  `mx-ui` の5リポジトリは `main` / `exports["."]` がまだ `./src/index.ts` を指したままで、
  `mc-compose` 以外は不適合として赤くなる(`mc-compose` は §4 の名指し例外)。残り10リポジトリ
  (`mc-kernel` `mc-audio` `mc-meshing` `mc-noise` `mc-physics` `mc-playground-kit` `mc-render`
  `mc-save` `mc-sim` `mc-worldgen`)は既に `./dist/index.js` 形に到達済み — ただしビルド手段
  (esbuild バンドル、tsdown など)は PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」 が禁止する形のまま残っている
  リポジトリがあり、この判定項目はそこまでは見ていない(ビルドスクリプトの中身は本チェックの
  対象外)。
- **廃止物の不在**: `mc-audio` の `scripts/check-dependency-whitelist.ts`、`mx-gameplay` の
  `api-lock.md` と `scripts/check-dependency-whitelist.ts` が残存。他13リポジトリは既に削除済み。
- **CI**: `packages: read` は `mc-kernel` を除く、確認できた14リポジトリで既に設置済み。SHA
  ピン留めも確認できた15リポジトリ全部で完了(2026-08-01時点の「タグ参照のまま」という記述は
  もう現実と一致しない)。`mc-dev-meta` は同期スナップショットに含まれないため未確認。
- **Dependabot**: 確認できた15リポジトリ全部に既に設置済み(2026-08-01時点の「どこにも存在しない」
  はもう現実と一致しない)。`mc-dev-meta` は未確認。
- **release.yaml**: `mc-kernel` のみ設置済み。他14リポジトリ(`mc-dev-meta` を除く)は未設置。
- **カバレッジ100%**: `mc-kernel` `mc-audio` `mc-meshing` `mc-noise` `mc-physics`
  `mc-playground-kit` `mc-render` `mc-save` `mc-sim` `mc-worldgen` の10リポジトリは既に
  100%。`mc-compose` `mx-gameplay` `mx-multiplayer` `mx-redstone` `mx-ui` の5リポジトリは
  99%のまま(2026-08-01時点は逆に `mx-gameplay` `mx-redstone` `mx-ui` が「既に有効」側だったが、
  以後閾値が100%へ上がったため、99%のこの5リポジトリは今回あらためて未達側になる)。

この数値は再実行すれば更新されるので、移行の進捗指標として使えます。
`bash scripts/check-conformance.sh <repos-dir>` を引数なしのリポジトリ一覧で実行すれば
`mc-dev-meta` を含む16リポジトリ全部の判定を再取得できます(本書のこの表は
`mc-dev-meta` を含まない同期スナップショットに対する実行結果です)。

## Shared ast-grep conformance

Consumer repositories can run the shared rules through the composite action in `nerima-games/.github`. Pin the action to a 40-character commit SHA and set `public-api-baseline` to a JSON file committed in the consumer repository:

```yaml
- name: Check shared ast-grep conformance
  uses: nerima-games/.github/conformance/ast-grep@<40-character-commit-sha>
  with:
    public-api-baseline: .ast-grep/public-api-baseline.json
```

The baseline path is relative to the consumer repository. The action supplies `jq` from a pinned Nixpkgs revision before entering the consumer's `nix develop`, so consumers do not need to add `jq` to their dev shell. The consumer dev shell must provide `ast-grep`; the action uses the consumer's selected version and fails if it is missing. The shared flake template includes both tools. Without this input, the action requires zero findings from all three rule packs. With it, `core` and `effect3` still require zero findings, while the `public-api` rules use a ratchet: CI fails when a scan finds a violation missing from the baseline or when a baseline count is higher than the current matches. If only some duplicate matches are fixed, reduce that tuple's count. If all matches are fixed, remove the tuple. Rerun the baseline generator below to update counts and remove empty tuples, then commit the smaller file.

### Decisions

The action provisions only `jq`, because it processes the scanner's JSON output. It leaves `ast-grep` in the consumer dev shell so each consumer keeps its chosen version. A consumer without `ast-grep` fails during `nix develop`; the action does not silently substitute another version.

W4-R16 is the policy decision to keep every shared rule enabled while consumers record existing public API findings during migration. The shared scan on mc-render PR #48 reported 573 findings, including 536 findings where exported signatures exposed raw TypeScript types such as `string` and `number`. Converting those types in the mc-render 0.9.0 release would delay mx-ui and the next rollout wave. The published kernel, sim, and worldgen packages had not yet been scanned, so their finding counts were unknown. The ruling schedules a cross-repository cleanup wave before the next rollout wave. Every baseline must be empty before the W6 rollout; W6-6 is its final verification gate. The action enforces the per-run ratchet, while the rollout gate checks the deadline.

To generate or shrink a baseline, check out the shared `.github` repository at `../.github`, then run this command from the consumer repository's Nix dev shell. Since this invokes the scanner directly, that shell must provide both `ast-grep` and `jq`:

```console
$ bash ../.github/conformance/ast-grep/scan.sh --write-baseline .ast-grep/public-api-baseline.json "$PWD"
```
