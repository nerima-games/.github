# 移行実行手順書(MIGRATION_RUNBOOK.md)

本書は、既存の nerima-games 16 リポジトリ(`mc-audio` `mc-compose` `mc-dev-meta` `mc-kernel`
`mc-meshing` `mc-noise` `mc-physics` `mc-playground-kit` `mc-render` `mc-save` `mc-sim`
`mc-worldgen` `mx-gameplay` `mx-multiplayer` `mx-redstone` `mx-ui`)を、本 org が今回策定した
標準群(`PACKAGE_STANDARD.md` `API_STANDARD.md` `TEST_STANDARD.md` `SUPPLY_CHAIN.md`
`RELEASE_STANDARD.md`、および未執筆の `DEPENDENCY_POLICY.md`)へ移行するための、
**具体的な手順書**である。各標準文書が「あるべき姿(目標状態)」を定めるのに対し、
本書は「どの順で何をコマンド1つ単位まで実行すれば、そこへ到達するか」だけを定める。
判断根拠・設計理由は書かない。理由が要る箇所はすべて該当する標準文書への参照に留める。

**現状(2026-08-01 時点)の確認方法**: 各手順の「現状」欄は、実際に16リポジトリを
`ls` / `grep` / `git` で調べた結果であり、推測ではない。`DEPENDENCY_POLICY.md` は
本書執筆時点でまだ存在しないため、手順4の「不足エントリ」は各リポジトリ自身の
`docs/architecture.md` が宣言する親リポジトリ一覧から導出した暫定値である。
`DEPENDENCY_POLICY.md` が書かれた時点で、この暫定値と食い違いがないか再確認すること。

## 実行順序についての注記

以下は 1〜8 の番号順に記載するが、**手順2・3(削除系)を手順1(`src/` 移動)より先に
終わらせておくと手戻りが少ない**。理由: 手順1で `test/*.test.ts` の相対 import を
一括で書き換えるとき、後で削除する `test/api-lock.test.ts` /
`test/check-dependency-whitelist.test.ts` まで書き換えてしまうのは無駄である。
必須の順序ではないが、推奨する実施順は次の通り。

```
2 (api-lock 廃止) → 3 (dependency-whitelist 廃止) → 1 (src/ 再構成) → 4 (依存 drift 修正)
→ 5 (SHA 固定) → 6 (Dependabot) → 7 (カバレッジゲート) → 8 (changesets)
```

---

## 手順1: `src/` 再構成

**why**: 配布物(`src/` の中)と非配布物(`test/` `scripts/` `apps/` `docs/` など)の境界を
「`src/` の内か外か」という1つの問いに単純化するため。詳細な理由は
[PACKAGE_STANDARD.md「なぜ `src/` か」](PACKAGE_STANDARD.md#なぜ-src-か) を参照。
`apps/` は対象外(`src/` の外、リポジトリ直下のきょうだいのまま)。

対象: 全16リポジトリ。

1. `mkdir -p src` してから、リポジトリ直下にある配布対象ディレクトリ/ファイルを移動する。
   `application/` `stages/` は存在する場合のみ移動する(下記サマリ表参照)。

   ```bash
   git mv index.ts src/index.ts
   git mv domain src/domain
   [ -d application ] && git mv application src/application
   [ -d stages ] && git mv stages src/stages
   ```

2. **`apps/` は移動しない。** リポジトリ直下に残す。

3. `package.json` を書き換える([PACKAGE_STANDARD.md「`package.json` の必須フィールドと
   スクリプト」](PACKAGE_STANDARD.md#packagejson-の必須フィールドとスクリプト) の表どおり)。

   | フィールド | 移行後の値 |
   |---|---|
   | `main` | `"./src/index.ts"` |
   | `types` | `"./src/index.ts"` |
   | `exports["."]` | `"./src/index.ts"` |
   | `files` | 先頭要素を `"src"` に統合(`"index.ts", "domain", "application", ...` のような個別列挙をやめる。`"tsconfig.base.json"` `"LICENSE"` `"README.md"` などそれ以外の要素はそのまま残す) |
   | `scripts.lint` | 対象パス先頭を `src`(`apps` `test-browser` を持つリポジトリはそれらのパスを維持したまま並べる) |
   | `scripts.lint:fix` | 同上 |

4. `vitest.config.ts` の `coverage.include` を書き換える。

   | 軸 | 値 |
   |---|---|
   | 最小(`application/` `stages/` なし) | `['src/index.ts', 'src/domain/**/*.ts']` |
   | `application/` あり | 上記に `'src/application/**/*.ts'` を追加 |
   | `stages/` あり | 上記に `'src/stages/**/*.ts'` を追加 |

5. `tsconfig.*.json`(`tsconfig.json` / `tsconfig.build.json` / `tsconfig.test.json` /
   `tsconfig.preview.json`[`apps/` がある場合のみ])の `include` を、
   [PACKAGE_STANDARD.md「必須 tsconfig ファイル」](PACKAGE_STANDARD.md#必須-tsconfig-ファイル)
   の表どおり `src/` 前提のパスへ書き換える。

6. `test/*.test.ts`(および `mx-ui` の場合は `test-browser/*.spec.ts`)内の相対 import を書き換える。
   `test/` は `src/` と同階層のきょうだいのままなので、`src/` を経由する1段が増える。

   ```bash
   # 例: test/ 配下の *.test.ts に対して
   grep -rl "from '\.\./\(domain\|application\|stages\|index\)" test | while read f; do
     sed -i '' -E "s#from '\.\./(domain|application|stages|index)#from '../src/\1#g" "$f"
   done
   ```

   sed は雑な一括置換なので、置換後に `pnpm typecheck` で漏れ・誤爆がないか必ず確認すること。

7. **`mx-ui` 固有の注意**: `test-browser/*.spec.ts` および `playwright.config.ts` が
   `domain/` `application/` を相対 import している場合、同様に `src/` 経由へ書き換える。
   `playwright.config.ts` 自体は `src/` に移動しない(`test/` `scripts/` と同じくきょうだいのまま)。

**verification**: `pnpm verify`(`typecheck && lint && test`)が green になること。加えて
`ls` でリポジトリ直下に `index.ts` `domain` `application` `stages` が残っていないこと
(`apps` は残っているのが正しい)、`git status` で移動漏れがないことを確認する。

---

## 手順2: `api-lock` 機構の全廃

**why**: 自動 API スナップショット/diff ツールを持たない方針への統一。理由と経緯は
[API_STANDARD.md §4](API_STANDARD.md#4-自動-apiロックスナップショットツールは使わない) を参照。
1.0.0 昇格も日数計測ベースの自動ゲートから、maintainer の裁量判断([RELEASE_STANDARD.md §4](RELEASE_STANDARD.md#4-0x--100-昇格ポリシー旧ゲートの廃止))へ切り替える。

対象: 全16リポジトリ。**16リポジトリ全てが `api-lock.md` / `scripts/api-lock.ts` /
`test/api-lock.test.ts` の3点セットを保持していることを確認済み(2026-08-01)。**

1. 3ファイルを削除する。

   ```bash
   git rm api-lock.md scripts/api-lock.ts test/api-lock.test.ts
   ```

2. `package.json` の `scripts` から `api:check` / `api:update` を削除する。
   `scripts.verify` から `&& pnpm api:check` を削る(手順3の `check:deps` 削除と合わせて、
   最終的に `pnpm typecheck && pnpm lint && pnpm test` の3段に確定させる。1回で両方削ってもよい)。

3. `.github/workflows/ci.yaml` から「API lock」ステップ(`pnpm api:check` を実行するステップ)を削除する。

4. `docs/versioning.md`(全16リポジトリに存在)を更新し、「4週間 API 無変更で凍結」という
   freeze-clock 言語を削除する。代わりに「1.0.0 への昇格は maintainer の裁量判断による」
   ([RELEASE_STANDARD.md §4.2](RELEASE_STANDARD.md#42-新しい昇格ポリシー人間による裁量判断))
   と書き換える。

5. `docs/freeze-checklist.md` を持つリポジトリ(**`mc-kernel` のみ確認済み**)は同様に
   凍結ウィンドウ計測の記述を削除・書き換える。

6. **`mc-dev-meta` 固有の追加作業(フォローアップ)**: `mc-dev-meta` は他の15リポジトリの
   `api-lock.md` の凍結ウィンドウを読みに行く `scripts/check-api-lock-window.ts`
   (`package.json` の `check:api-window` スクリプト)を持つ。`api-lock.md` が org 全体から
   消えるため、このスクリプトと `scripts.verify` からの参照も合わせて削除する
   (本手順の必須3点セットには含まれないが、放置すると壊れたスクリプトが残る)。

**verification**: `pnpm verify` が通ること。`grep -rn "api-lock\|api:check\|api:update" .`
(`node_modules` を除く)がリポジトリ内に残存参照ゼロであることを確認する。

---

## 手順3: `check-dependency-whitelist` の廃止 + oxlint ルール追加

**why**: Tier 間の依存許可リストを、カスタムスクリプトではなく `.oxlintrc.json` の
`no-restricted-imports` に一本化するため。詳細は
[API_STANDARD.md](API_STANDARD.md) 系ではなく `DEPENDENCY_POLICY.md`(未執筆)が扱う。
Tier 別の禁止パターンの中身はリポジトリごとに違ってよく、byte-identical であることは
適合の条件ではない([PACKAGE_STANDARD.md「`scripts/check-dependency-whitelist.ts` の廃止」](PACKAGE_STANDARD.md#scriptscheck-dependency-whitelistts-の廃止)参照)。

対象: 全16リポジトリ。**現状確認(2026-08-01)**:

- `scripts/check-dependency-whitelist.ts` は全16リポジトリに存在する。
- `test/check-dependency-whitelist.test.ts` は **`mc-audio` `mc-save` `mc-worldgen` の3リポジトリには存在しない**
  (スクリプトのみでテストを持たない)。残り13リポジトリは両方持つ。

1. 削除する(存在するファイルのみ)。

   ```bash
   git rm scripts/check-dependency-whitelist.ts
   [ -f test/check-dependency-whitelist.test.ts ] && git rm test/check-dependency-whitelist.test.ts
   ```

2. `package.json` の `scripts` から `check:deps` を削除し、`scripts.verify` を
   `"pnpm typecheck && pnpm lint && pnpm test"` に確定させる(手順2と合わせて1回で行ってよい)。

3. `.oxlintrc.json` に `no-restricted-imports` ブロックを追加/拡張する。
   `mc-kernel/.oxlintrc.json` が既に持つ形(`effect` のデフォルト import 禁止)を土台に、
   自リポジトリの Tier が禁止すべき `@nerima-games/*` import パターンを足す
   (許可される親・禁止される兄弟/子は `DEPENDENCY_POLICY.md` を参照。同文書が
   まだ無い場合は各リポジトリの `docs/architecture.md` の依存グラフ節を暫定的な根拠とする)。

   ```jsonc
   "no-restricted-imports": [
     "warn",
     {
       "name": "effect",
       "message": "Please use named imports from 'effect' package",
       "importNames": ["default"]
     },
     {
       "name": "@nerima-games/mc-sim",
       "message": "not a declared parent of this repository; see docs/architecture.md"
     }
     // ... 自リポジトリの Tier が禁止する @nerima-games/* を列挙
   ]
   ```

4. 「時刻源の直接呼び出し禁止」のように oxlint の既存ルールで表現できないチェックは、
   oxlint がそのルールを実装するまでの間、個別スクリプトとして `scripts/` に残すかどうかを
   各リポジトリの裁量に委ねる(org 標準としては要求しない)。

5. **`mc-dev-meta` 固有の注意**: `mc-dev-meta` の `scripts.verify` は他リポジトリと異なり
   `pnpm check:mirrors`(`scripts/check-mirrors.ts`)という固有ステップを追加で持つ。
   これは `check-dependency-whitelist.ts` 廃止の直接対象ではないため削除しないが、
   `check:deps` 削除後の `verify` 定義に `check:mirrors` を残すかどうかは
   `mc-dev-meta` の維持担当者が個別に判断すること。

**verification**: `pnpm verify` が通ること。`.oxlintrc.json` に追加した
`no-restricted-imports` パターンに実際にひっかかるコードを一時的に書いて
`pnpm lint` が検出することを確認してから削除する(ルールが実際に効いているかの動作確認)。

---

## 手順4: 依存 drift の修正(4リポジトリのみ)

**why**: `package.json#dependencies` を、各リポジトリの `docs/architecture.md` が宣言する
4層グラフ上の「親」と一致させるため。`宣言と実体の一致`
(`import する @nerima-games/* は package.json に無ければ違反`)は
`mc-worldgen/docs/architecture.md` §2 などが明記する org 共通ルールであり、
現状はこれが未達の4リポジトリがある。

対象: **`mc-worldgen` `mx-redstone` `mx-ui` `mx-multiplayer` の4リポジトリのみ**
(他12リポジトリはこの意味での drift を確認していない)。

**現状確認(2026-08-01)**: 4リポジトリとも `package.json#dependencies` は `effect` 1つのみ。
一方 `domain/` 内に「本来 `@nerima-games/*` の実パッケージから import すべきだが、
未公開/未整備を理由に一時的にローカル複製している」という `PROVISIONAL LOCAL MIRROR`
コメント付きモジュール(例: `mc-worldgen/domain/kernel-vocabulary.ts`、
`mc-worldgen/domain/save-format-port.ts`)が存在する。**2026-08-01 時点では
これら4リポジトリの `domain/` `application/` `stages/` `index.ts` に実際の
`import ... from '@nerima-games/...'` 文は1つも無い**(すべてミラー実装で代替されている)ため、
`pnpm install` や型検査が現時点で壊れているわけではない。今回の追加は、
①ドキュメントが宣言する親と `package.json` の実体を先に一致させておくこと、
②将来ミラーを実 import に置き換える際に無駄な `package.json` 変更を挟まないための予防措置である。

| リポジトリ | 現状の `dependencies` | `docs/architecture.md` が宣言する親 | 不足エントリ |
|---|---|---|---|
| `mc-worldgen` | `effect` のみ | `mc-kernel`(普遍)、`mc-noise`、`mc-save` | `@nerima-games/mc-kernel`(0.2.8)、`@nerima-games/mc-noise`(0.1.0)、`@nerima-games/mc-save`(0.1.0) |
| `mx-redstone` | `effect` のみ | `mc-kernel`(普遍)、`mc-sim`、`mc-worldgen` | `@nerima-games/mc-kernel`(0.2.8)、`@nerima-games/mc-sim`(0.1.24)、`@nerima-games/mc-worldgen`(0.1.1) |
| `mx-ui` | `effect` のみ | `mc-kernel`(普遍)、`mc-sim`、`mc-audio` | `@nerima-games/mc-kernel`(0.2.8)、`@nerima-games/mc-sim`(0.1.24)、`@nerima-games/mc-audio`(0.1.0) |
| `mx-multiplayer` | `effect` のみ | `mc-kernel`(普遍)、`mc-sim`のみ | `@nerima-games/mc-kernel`(0.2.8)、`@nerima-games/mc-sim`(0.1.24) |

括弧内のバージョンは2026-08-01 時点の各パッケージの `package.json#version` であり、
`mc-render`(`"@nerima-games/mc-kernel": "0.2.0"`)や `mc-sim`
(`"@nerima-games/mc-kernel": "0.2.8"`)に倣い、`^` を付けない完全指定で追加する。
**`DEPENDENCY_POLICY.md` が書かれ次第、上表の「宣言する親」列と食い違いがないか再確認すること**
(本表は同文書が存在しない間の暫定的な根拠として、各リポジトリ自身の
`docs/architecture.md` から機械的に抜き出したものである)。

1. 上表の不足エントリを `package.json#dependencies` に追加する。
2. `pnpm install` を実行し `pnpm-lock.yaml` を更新する。

**verification**: `pnpm install`(lockfile 差分がエントリ追加分のみであること)、続けて
`pnpm verify`。さらに手順3で追加した `.oxlintrc.json` の `no-restricted-imports` が
今回追加した依存を禁止パターンに含めていないか(誤って自分自身の親を lint で弾いていないか)
`pnpm lint` で確認する。

---

## 手順5: GitHub Actions の SHA 固定

**why**: `uses:` のタグ参照(`@v6` など)は上流が任意のタイミングで指す commit を
差し替えられる可変参照であり、サプライチェーン攻撃に対して脆弱。フル40桁 commit SHA
固定 + `# vX` コメントで、再現性と可読性を両立する。詳細な脅威モデルは
[SUPPLY_CHAIN.md「アクションの固定」](SUPPLY_CHAIN.md#アクションの固定) を参照。

対象: 全16リポジトリの `.github/workflows/ci.yaml`(および同種のワークフローがあれば同様に)。

**現状確認(2026-08-01)**:

- `pnpm/action-setup` は既に全16リポジトリで SHA 固定済み
  (`pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1 # v4`)。これは変更不要。
- `actions/checkout` `actions/setup-node` `actions/upload-artifact` の3つは全リポジトリで
  タグ止まり。`mc-compose` `mc-render` `mx-gameplay` の3リポジトリは `@v4`、
  残り13リポジトリは `@v6`。

**参照実装**: `mc-kernel` の未マージブランチ `feat/kernel-api-hardening`
(worktree: `mc-kernel/.worktrees/feat-kernel-api-hardening`)の `.github/workflows/docs.yaml`
が、この形をすでに実践している(該当ワークフローは `docs.yaml` であり `ci.yaml` とは
対象アクションが異なるが、書式は共通)。

```yaml
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5
uses: actions/configure-pages@45bfe0192ca1faeb007ade9deae92b16b8254a0d # v6
uses: actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9 # v5
uses: actions/deploy-pages@cd2ce8fcbc39b97be8ca5fce6e763baed58fa128 # v5
```

`ci.yaml` が実際に使う3アクションの `v6` タグの SHA は `SUPPLY_CHAIN.md` が
`git ls-remote --tags` で実測済みの値として以下を示している。

```yaml
# Before
- uses: actions/checkout@v6
- uses: actions/setup-node@v6
- uses: actions/upload-artifact@v6

# After
- uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6
- uses: actions/setup-node@249970729cb0ef3589644e2896645e5dc5ba9c38 # v6
- uses: actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f # v6
```

`mc-compose` `mc-render` `mx-gameplay` の3リポジトリは現状 `@v4` のため、
`v6` へ上げてから上記 SHA に固定するか、`v4` のまま SHA だけ固定するかを選べるが、
**バージョン統一(`v4`→`v6`)は本手順のスコープ外**であり、SHA 化だけを行うことでもよい。
`v4` のまま固定する場合は `actions/checkout` 等の `v4` タグの SHA を別途取得すること。

1. 3アクションの `uses:` 行を SHA 固定 + `# vX` コメントの形に書き換える。
   **値を本書から機械的にコピーしてよいのは上記の `v6` の3行のみ**であり、
   それ以外のバージョン・アクションを固定する場合は
   `git ls-remote --tags https://github.com/<owner>/<repo> vX` などで実際に取得し、
   推測で SHA を書かない。
2. `actions/checkout` に `with: persist-credentials: false` を追加する
   (`GITHUB_TOKEN` を checkout 後のステップに残さないため。
   [SUPPLY_CHAIN.md](SUPPLY_CHAIN.md) §「アクションの固定」参照)。
3. ワークフロー先頭の `permissions:` は既存の `contents: read` 宣言を維持する
   (16リポジトリすべて既に宣言済みであることを確認済み。これは維持基準線であり変更不要)。

**verification**: `grep -E "@[0-9a-f]{40}" .github/workflows/ci.yaml` で3アクション行が
すべて40桁hexになっていることを確認する。CI を一度流し、`Checkout` / `Setup Node.js` /
アーティファクトアップロードの各ステップが正常完了することを確認する
(SHA の取り違えは該当ステップで即座に失敗するため検出は容易)。

---

## 手順6: Dependabot の追加

**why**: SHA 固定(手順5)は「今ある参照が動かない」ことを保証するが、
「新しいバージョンに気づく」ことは保証しない。週次の自動更新 PR で両方を揃える。
詳細は [SUPPLY_CHAIN.md「Dependabot」](SUPPLY_CHAIN.md#dependabot) を参照。

対象: 全16リポジトリ。**現状、org のどのリポジトリにも `.github/dependabot.yml` は存在しない
(2026-08-01 確認済み)。**

1. `.github/dependabot.yml` を新規作成する。最低限 `github-actions` エコシステムを
   weekly で有効化する。`SUPPLY_CHAIN.md` は `npm` エコシステムの併記も推奨しており、
   `pnpm-lock.yaml` をコミットしている15リポジトリ(`mc-dev-meta` を除く)ではそのまま追加できる。

   ```yaml
   version: 2
   updates:
     - package-ecosystem: "github-actions"
       directory: "/"
       schedule:
         interval: "weekly"

     - package-ecosystem: "npm"
       directory: "/"
       schedule:
         interval: "weekly"
   ```

2. **`mc-dev-meta` 固有の注意**: `pnpm-lock.yaml` を意図的に `.gitignore` している
   (ワークスペースルートのロックファイルが `repos/` 配下の別ワークスペースを巻き込むため)。
   ロックファイルが無くても Dependabot は `package.json` の caret 範囲に対して PR を作成できるため、
   `npm` エントリは同様に追加してよい(ロックファイル不在は追加を妨げる理由にならない)。

**verification**: GitHub 上で `.github/dependabot.yml` の構文エラーが無いこと
(Insights > Dependency graph > Dependabot、または PR 上の構文チェック)を確認する。
Dependabot が実際に PR を作成するまで最大1週間かかる可能性がある点に注意し、
即時の確認はできないことを前提に扱う。

---

## 手順7: カバレッジ4指標99%ゲートの即時有効化

**why**: 組織としての決定([TEST_STANDARD.md §3](TEST_STANDARD.md#3-カバレッジゲート-4-指標-99即日全リポジトリ必須段階移行なし))
により、猶予期間や段階ロールアウトを設けず全16リポジトリで即時に適用する。

対象: 全16リポジトリ。**現状確認(2026-08-01)**:

- **既に有効(アンコメント済み)**: `mc-kernel` `mx-ui` `mx-gameplay` `mx-redstone` の4リポジトリ。
  この4リポジトリは本手順の対象外(作業不要)。
- **コメントアウトされたまま(要有効化)**: 残り12リポジトリ
  (`mc-audio` `mc-compose` `mc-dev-meta` `mc-meshing` `mc-noise` `mc-physics`
  `mc-playground-kit` `mc-render` `mc-save` `mc-sim` `mc-worldgen` `mx-multiplayer`)。

1. 対象12リポジトリの `vitest.config.ts` で、コメントアウトされている
   `thresholds: { branches: 99, functions: 99, lines: 99, statements: 99 },` 行の
   コメントを外す([TEST_STANDARD.md §3.2](TEST_STANDARD.md#32-設定の実例mc-kernel) の
   `mc-kernel` の実例をそのまま踏襲してよい)。
2. `.github/workflows/ci.yaml` に `pnpm test:coverage`(`vitest run --coverage`)を
   `pnpm verify` とは別の必須ゲートとして追加する(`verify` に含めない。
   [TEST_STANDARD.md §1](TEST_STANDARD.md#1-pnpm-verify-の構成) 参照)。

**既知の受容済み結果(先送りしない)**: 次の3リポジトリは、この手順を実行した瞬間に
CI が赤くなることが判明済みである。これは延期の理由にせず、既知・受容済みの結果として扱う。

| リポジトリ | 実測(2026-08-01時点) | 状態 |
|---|---|---|
| `mc-audio` | statements/branches/lines 95.52%、**functions 84.12%(53/63)** | 4指標とも99%未達 → CI 赤 |
| `mc-compose` | `coverage/coverage-final.json` が存在せずベースライン未計測 | `pnpm test:coverage` を1回走らせて現在地を明らかにすることが前提作業 |
| `mc-playground-kit` | statements/lines 98.51%、branches 100%、**functions 96.29%** | functions のみ99%未達 → CI 赤 |

**verification**: `pnpm test:coverage` をローカルで実行し、しきい値未達なら非ゼロ終了することを
確認する。CI に追加したカバレッジゲートのステップが(上記3リポジトリでは red、他13リポジトリでは
green という)期待通りの結果になることを確認する。

---

## 手順8: changesets の導入

**why**: バージョニングと CHANGELOG 生成を changesets に一本化し、GitHub Packages への
公開フローを統一する。詳細は [RELEASE_STANDARD.md §1](RELEASE_STANDARD.md#1-changesets-導入) を参照。

対象: **`mc-dev-meta` を除く15リポジトリ**。`mc-dev-meta` は `package.json` に
`"private": true` を明示し "Never published." と説明する非公開の pnpm workspace
バインダーであり、[RELEASE_STANDARD.md](RELEASE_STANDARD.md#0-現状このドキュメント作成時点で確認した事実) が
明示的にスコープ外としている。

**現状確認(2026-08-01)**: `.changeset/` ディレクトリ、`@changesets/cli` への依存は
全16リポジトリに存在しない。

1. `@changesets/cli` を `devDependency` として追加し、初期化する。

   ```bash
   pnpm add -D @changesets/cli
   pnpm changeset init
   ```

2. 生成された `.changeset/config.json` を編集する。

   - `access`: `"restricted"`(各リポジトリの `package.json#publishConfig.access` と一致させる)
   - `baseBranch`: `"main"`
   - `changelog`: 既定の `@changesets/changelog-git` ではなく `@changesets/changelog-github` を推奨
     (PR 番号・リポジトリへのリンクが CHANGELOG に入る)
   - `registry`(または publish 先の設定): 各リポジトリの `publishConfig`
     (`https://npm.pkg.github.com`)と一致させる

3. CI(`ci.yaml`)に `changeset status --since=main` 相当のチェックを追加し、
   ユーザー向け変更を含む PR で changeset の付け忘れを検出する
   (`docs/` のみの変更など明らかに not-user-facing な PR は除く)。

4. publish ジョブの新設は本手順の対象外とする。認証・トリガー条件などの詳細設計は
   [RELEASE_STANDARD.md §3](RELEASE_STANDARD.md#3-ci-publish-ジョブの設計) を参照して
   別途行うこと。

**verification**: `pnpm changeset --help` が実行できる(CLI 導入確認)。
`pnpm changeset status` が `baseBranch` との差分検出として動作すること
(実際に空の changeset を1つ作って確認してよい)。

---

## 16リポジトリ × 手順 適用差分サマリ

`○` = 標準的な作業がそのまま適用される。差分がある場合は具体的に記載する。
手順2・3・5・6 は全16リポジトリで同一作業のため列を割かず、表の外の注記のみとする。

| # | リポジトリ | Tier | `application/` | `stages/` | `apps/` | `test-browser/` | 手順1の備考 | 手順4対象 | 手順7の現状 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `mc-audio` | Tier1 | – | – | ○ | – | `apps/` あり。lint 対象パスに `apps` を追加 | – | **要有効化・既知で赤** |
| 2 | `mc-compose` | Tier4 | – | – | ○ | – | `apps/` あり | – | 要有効化・**ベースライン未計測** |
| 3 | `mc-dev-meta` | 層外 | – | – | – | – | 最小構成(`domain/` のみ)。手順2/3で固有スクリプトの後始末あり(本文参照) | – | 要有効化 |
| 4 | `mc-kernel` | Tier1 | – | – | – | – | 最小構成。3軸すべて No の基準形 | – | 既に有効 |
| 5 | `mc-meshing` | Tier1 | – | – | – | – | 最小構成 | – | 要有効化 |
| 6 | `mc-noise` | Tier1 | – | – | – | – | 最小構成 | – | 要有効化 |
| 7 | `mc-physics` | Tier1 | – | – | – | – | 最小構成 | – | 要有効化 |
| 8 | `mc-playground-kit` | Tier2 | ○ | – | ○ | – | `application/` `apps/` あり | – | 要有効化・既知で赤 |
| 9 | `mc-render` | Tier2 | ○ | ○ | ○ | – | 3軸すべて Yes。最も対象ファイルが多い | – | 要有効化 |
| 10 | `mc-save` | Tier1 | – | – | – | – | 最小構成。手順3のテストファイル欠如あり | – | 要有効化 |
| 11 | `mc-sim` | Tier2 | ○ | ○ | ○ | – | 3軸すべて Yes | – | 要有効化 |
| 12 | `mc-worldgen` | Tier2 | ○ | – | ○ | – | `application/` `apps/` あり。手順3のテストファイル欠如あり | **対象** | 要有効化 |
| 13 | `mx-gameplay` | Tier3 | – | ○ | ○ | – | `stages/` `apps/` あり(`application/` なし) | – | 既に有効 |
| 14 | `mx-multiplayer` | Tier3 | – | ○ | ○ | – | `stages/` `apps/` あり | **対象** | 要有効化 |
| 15 | `mx-redstone` | Tier3 | ○ | ○ | ○ | – | 3軸すべて Yes | **対象** | 既に有効 |
| 16 | `mx-ui` | Tier3 | ○ | ○ | ○ | **○** | 3軸すべて Yes、かつ **`test-browser/` + `playwright.config.ts` を持つ唯一のリポジトリ**。手順1で `test-browser/*.spec.ts` の相対 import 書き換えに追加の注意が要る | **対象** | 既に有効 |

**手順4(依存 drift 修正)が適用されるのは `mc-worldgen` `mx-redstone` `mx-ui`
`mx-multiplayer` の4リポジトリのみ**であり、詳細は手順4本文の表を参照。

**手順3のテストファイル欠如**: `mc-audio` `mc-save` `mc-worldgen` の3リポジトリは
`scripts/check-dependency-whitelist.ts` は持つが `test/check-dependency-whitelist.test.ts`
は持たない。削除対象がスクリプト1点のみである点に注意する。

**手順6・8での `mc-dev-meta` 例外**:

- 手順6(Dependabot): `pnpm-lock.yaml` が意図的に `.gitignore` されているが、
  `npm` エコシステムの追加を妨げない(本文参照)。
- 手順8(changesets): `mc-dev-meta` は `"private": true` の非公開パッケージであり
  **対象外**。changesets を導入するのは残り15リポジトリ。

**手順7で CI が既知で赤くなる3リポジトリ**: `mc-audio` `mc-compose` `mc-playground-kit`。
延期・しきい値緩和は行わない(手順7本文参照)。

---

## 関連文書

- [PACKAGE_STANDARD.md](PACKAGE_STANDARD.md) — 手順1の目標ディレクトリ構成
- [API_STANDARD.md](API_STANDARD.md) — 手順2の公開 API の定義・破壊的変更判定
- [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md) — 手順3・4の Tier 別依存許可(本書執筆時点で未執筆)
- [TEST_STANDARD.md](TEST_STANDARD.md) — 手順3の `verify` 定義、手順7のカバレッジゲート
- [SUPPLY_CHAIN.md](SUPPLY_CHAIN.md) — 手順5・6のアクション固定・Dependabot
- [RELEASE_STANDARD.md](RELEASE_STANDARD.md) — 手順8の changesets・公開先・昇格ポリシー
- [DOCS_STANDARD.md](DOCS_STANDARD.md) — 手順2で書き換える `docs/versioning.md` 等のページ型
- [DECISIONS.md](DECISIONS.md) — 本書が前提とする各決定(DEC-0001〜DEC-0006)の記録
