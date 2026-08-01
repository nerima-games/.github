# nerima-games コーディング規約

[PACKAGE_STANDARD.md](PACKAGE_STANDARD.md)（未執筆）がリポジトリの外形を決めるのに対して、この文書はソースコードの中身を決めます。
API の形（エンドポイント設計・スキーマ）は [API_STANDARD.md](API_STANDARD.md)（未執筆）、テストの書き方・カバレッジ基準は [TEST_STANDARD.md](TEST_STANDARD.md)（未執筆）、
リポジトリ間の依存許可リストは [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md)（未執筆）が扱います。
本文書はこの4つのどれとも重複させず、**ソースレベルのコーディング規約**（lint/型・ディレクトリ構造・命名）だけを扱います。

調査日は 2026-08-01 です。
対象は nerima-games org 配下 16 リポジトリ（mc-audio, mc-compose, mc-dev-meta, mc-kernel, mc-meshing, mc-noise,
mc-physics, mc-playground-kit, mc-render, mc-save, mc-sim, mc-worldgen, mx-gameplay, mx-multiplayer, mx-redstone, mx-ui）。
スタックは pnpm workspaces、Nix（flake.nix / direnv）、oxlint、vitest、TypeScript strict、Effect-ts です。
各規約には実際に読んだファイルの根拠を添えてあります。この `.github` リポジトリ自体はまだ scaffold
（`ISSUE_TEMPLATE/` `profile/` `scripts/` `templates/` `workflow-templates/` のみ）の段階で、本文書が最初の規約文書です。

## 決定事項の一覧

| 分類 | 規約 | 根拠 |
|---|---|---|
| Lint | oxlint のみ。prettier / biome / .editorconfig を置かない | `mc-kernel/.oxlintrc.json:3-4` |
| Lint 設定の共有 | 全リポジトリで同一。今後 `no-restricted-imports` のみリポジトリ固有に分岐する | 本文書 §1 |
| 型 | `strict: true` に加え全 strictness フラグを明示 | `mc-kernel/tsconfig.base.json:23-41` |
| 型定義 | データ型は `interface` でなく `type` | `mc-kernel/.oxlintrc.json:36` |
| コミット | Conventional Commits（`feat:` `fix:` `chore:` `test:` 等、任意でスコープ） | 本文書 §2（`mc-kernel` `mx-ui` の直近30件） |
| ディレクトリ | `domain/` は純粋型・純粋関数のみ、I/O・Effect サービス禁止 | `mc-sim/docs/responsibility.md`、`mc-kernel/docs/architecture.md:13,192` |
| ディレクトリ | `application/`（条件付き。PACKAGE_STANDARD.md 参照）は Effect サービスが Port を消費する層 | 本文書 §3 |
| 命名 | branded type（`WorldId` `StageId` 等）は `Brand.refined` で非空文字列などを保証 | `mc-kernel/domain/identifiers.ts:13-35` |
| 命名 | ファイルは kebab-case の `.ts` | 本文書 §4（`mc-kernel/domain/*`, `mc-sim/domain,application/*` 実測） |
| 命名 | StageId は `<所有リポジトリの接尾辞>:<stage名>` 形式 | `mc-kernel/domain/identifiers.ts:26`、`mc-sim/stages/stage-ids.ts:86` |

## 1. Lint 設定（oxlint）

### oxlint が唯一の lint/format 設定

`mc-kernel/.oxlintrc.json:3-4` のコメントに明記されている通りです。

> oxlint is the ONLY lint/format configuration in this repository.
> There is deliberately no prettier, no biome and no .editorconfig.

理由も同ファイルに書かれています。prettier や biome を並走させると二重の整形基盤を保守することになるため、
oxlint 単独に統一しています。

### 実際に有効なルール（`mc-kernel/.oxlintrc.json` を実読して確認）

`categories` はすべて `"warn"`（`correctness` `suspicious` `perf` `style` `restriction`、:25-29）で、
個別の `rules` がそれを上書きします。実際に読んで確認した主なルールは次の通りです。

TypeScript 固有（:36-45）:
- `@typescript-eslint/consistent-type-definitions": ["warn", "type"]` — データ型は `interface` でなく `type` を使う。
  例外は `plan.md §4.1` の契約（`StageRegistration`, `GameModule`）で、仕様書との文字面一致を優先し `interface` のまま
  にすると明記されている（:34-35）。
- `@typescript-eslint/no-explicit-any": "off"` — `any` は禁止していない。
- `@typescript-eslint/no-unused-vars": "warn"`, `no-floating-promises": "warn"`, `no-misused-new": "warn"`,
  `no-unnecessary-type-assertion": "warn"`, `no-var-requires": "warn"`,
  `prefer-enum-initializers"` / `prefer-for-of"` / `prefer-literal-enum-member": "warn"`。

無効化されているルール（:130-136）も明示されており、意図的な選択です。

- `@typescript-eslint/explicit-function-return-type": "off"`
- `@typescript-eslint/explicit-module-boundary-types": "off"`
- `@typescript-eslint/no-non-null-assertion": "off"`
- `no-case-declarations": "off"`, `no-constant-condition": "off"`, `no-param-reassign": "off"`, `no-plusplus": "off"`

Restriction 節にある `no-restricted-imports`（:119-126）は現状すべてのリポジトリで同一内容（`effect` の default
import 禁止）ですが、この規約はここで止まりません。**この移行以降、`.oxlintrc.json` の `no-restricted-imports`
節だけがリポジトリごとに分岐します**（詳細は [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md) 未執筆）。
それ以外の節（TypeScript / Correctness / Suspicious / Performance / Style の各ルール）は共有のまま変更しません。

### 実装されていないルールをコメントで記録する

`mc-kernel/.oxlintrc.json:6-13` に、`Date.now()` の禁止を `no-restricted-syntax` / `no-restricted-properties` /
`no-restricted-globals` で表現しようとした結果が記録されています。

> oxlint 0.12 does not implement `no-restricted-syntax` or `no-restricted-properties`, and while
> `no-restricted-globals` is listed by `oxlint --rules` it is not implemented either (no checkmark).
> Verified empirically against oxlint 0.12.0: a file containing `Date.now()` produces 0 diagnostics
> under all three rules. The ban is therefore enforced by `pnpm check:deps`
> (`scripts/check-dependency-whitelist.ts`) instead.

lint で表現できないルールを諦めて忘れるのではなく、(1) 設定ファイルに宣言だけ残し（:118 `no-restricted-globals`
は inert なまま残されている）、(2) 実際の強制はスクリプト側に置き、(3) その理由をコメントで残す、という型です。
新しいリポジトリで同種の制約が必要になったら、この3点セットに倣ってください。

### 3リポジトリで .oxlintrc.json を diff した結果

`mc-kernel` / `mx-ui` / `mc-audio` の `.oxlintrc.json` を実際に diff しました。

- `mc-kernel` と `mx-ui`: 差分なし（完全一致）。
- `mc-kernel` と `mc-audio`: 差分は2行のみで、`consistent-type-definitions` ルールに付いた
  「`plan.md §4.1` の契約は `interface` のまま」というコメント（mc-kernel 固有の注記）だけ。ルール本体に差はない。

つまり現時点でも `.oxlintrc.json` はほぼ全リポジトリ共通です。上述の通り、今後の変化点は
`no-restricted-imports` 節に限定する方針です。それ以外の節に手を入れる変更は、レビューで
「なぜこのリポジトリだけ違うのか」を問うべきです。

## 2. 型・strictness（tsconfig.base.json）

`mc-kernel/tsconfig.base.json` の冒頭コメント（:2-5）が方針そのものです。

> Shared compiler options for every tsconfig in this repository.
> Strictness policy: `strict: true` PLUS every additional strictness flag
> spelled out explicitly, so that a future TypeScript release changing a
> default cannot silently weaken this repository.

`strict: true` だけに頼らず、`strict` に含まれるフラグも含めて全部を明示することで、将来 TypeScript が
既定値を変えても本リポジトリの厳格さが黙って弱まらないようにしています。実際に有効な値（:23-41）は次の通りです。

```
strict: true
noImplicitAny: true
strictNullChecks: true
strictFunctionTypes: true
strictBindCallApply: true
strictPropertyInitialization: true
noImplicitThis: true
alwaysStrict: true
useUnknownInCatchVariables: true
exactOptionalPropertyTypes: true
noUncheckedIndexedAccess: true
noPropertyAccessFromIndexSignature: true
noImplicitOverride: true
noImplicitReturns: true
noFallthroughCasesInSwitch: true
noUnusedLocals: true
noUnusedParameters: true
allowUnreachableCode: false
allowUnusedLabels: false
```

新しいリポジトリの `tsconfig.base.json` はこの全項目をコピーし、削る場合はコメントで理由を書いてください
（`noImplicitAny` を外すような緩和は原則として認めません）。

このほか、`lib`（:12）は各リポジトリの役割で変わります。`mc-kernel` は
`"lib": ["ES2024"]` で DOM も Node グローバルも含めず、コメントに明記されている通り
「mc-kernel is platform-agnostic: no DOM, no WebWorker, no Node globals. Repos that need those
add them in their own tsconfig.base.json」という方針です。`mc-sim/docs/responsibility.md` の
非スコープ表（後述 §3）でも、この `lib` 設定が「THREE.js を import させない」ことを機械的に強制する
根拠として引かれています。

`noEmit: true`（:58）はビルド未着手の現状を反映したものであり、コメント（:55-57）に
「No build step yet. Every tsconfig here is check-only; `package.json#exports` points at TypeScript
source」とある通り、パッケージの `exports` は TypeScript ソースを直接指しています。ビルド/publish
パイプラインが整うまでの暫定です。

## 3. `domain/` と `application/` の境界

### domain/ は純粋型・純粋関数のみ

`mc-kernel/docs/architecture.md:13` が、`mc-kernel` を含む安定ライブラリ群の性質をこう記述しています。

> 安定ライブラリ | mc-kernel / mc-noise / mc-meshing / mc-physics / mc-save / mc-audio | 純粋関数・狭い界面・変更頻度が低い。相互独立で並行構築可能

`mc-kernel/docs/architecture.md:192` はさらに、`mc-kernel` が現状 `domain/` 単一構成であることを明記しています。

> mc-kernel は現在パッケージ分割しておらず、`domain/` 単一である。

`mc-sim/docs/responsibility.md` §3 は、`domain/` の境界を「非スコープ」の形で具体的に列挙している実例です。
以下は実際にそのファイルから引いたものです。

| 持たないもの | 正しい置き場 | 根拠 |
| --- | --- | --- |
| 描画。THREE.js の import 一切 | mc-render | `tsconfig.base.json` の `lib: ["ES2024"]`（DOM 無し）で機械的に防ぐ |
| 物理積分・AABB 衝突解決・voxel-DDA | mc-physics | mc-sim は `integrateBody()` と `resolveBody()` を呼ぶだけ |
| セーブフォーマットの実体（IndexedDB アダプタ・コーデック基盤） | mc-save | mc-sim は `defineFormat` で自分のフォーマットを定義する側 |

同文書 §3.2 の「判断手順」も、新しいコードの置き場を決める実務的な問いとして引用に値します。

> 1. THREE / DOM / WebAudio / IndexedDB に触るか → 触るなら mc-sim ではない
> 2. 消したらゲームのルールが変わるか、状態が消えるだけか → ルールなら体験モジュール
> 3. 他のリポジトリが「読む」ためのものか、「決める」ためのものか → 決めるなら所有者側へ
> 4. 6 つの下流のうち 2 つ以上が必要とするか → 1 つだけなら、その 1 つに置けないか再検討する

`domain/` 配下のファイルを実際に `grep` した結果、`mc-kernel/domain/*.ts` のほとんどは `effect` の
`Brand` だけを import しており（例: `identifiers.ts:7`, `coordinates.ts:24`, `quantities.ts:11`）、
Effect の実行可能な計算（`Effect.gen` や Layer 構築）は持ち込んでいません。

### 例外: Port の型定義は domain/ に置く

一点、素朴に「domain/ は effect を import しない」と規約化すると事実に反します。
`mc-kernel/domain/clock.ts:40` は `import { Context, Effect, Layer } from 'effect'` としており、
`ClockPort`（Context.Tag）と `ClockService`（`Effect.Effect<...>` を返すメソッドの型）を定義しています。
同ファイルの doc comment（:20-22）がこの位置づけを説明しています。

> The one legitimate place to read a global clock is the adapter that *implements* this Port,
> in whichever repository owns the platform layer.

つまり `domain/` が持ってよいのは **Port の型定義（契約）** までであり、Port を実装して実際に時計を読む
アダプタは `domain/` の外（消費側リポジトリの `application/` や、まだ書かれていないプラットフォーム層）に
置きます。`mc-sim/domain/kernel-vocabulary.ts:106` や `mc-worldgen/domain/kernel-vocabulary.ts:104` が
`Brand` に加え `Context, Effect, Layer` を import しているのも同じ理由（kernel の Port 型をミラーしている）
です。判断基準は「I/O を実行するか」であって「`effect` を import するかどうか」ではありません。

### application/ は Effect サービスが Port を消費する層

`application/` は全リポジトリに存在するわけではありません。実際に `application/` を持つのは
mc-sim・mx-ui・mc-worldgen・mc-playground-kit・mx-redstone・mc-render の6リポジトリで、
mc-kernel・mc-physics・mc-meshing・mc-audio・mc-noise・mc-save・mc-compose・mx-gameplay・mx-multiplayer・
mc-dev-meta は本調査時点で `application/` を持ちません（`domain/` のみ、または未使用）。
`application/` を置くかどうかの判断基準は [PACKAGE_STANDARD.md](PACKAGE_STANDARD.md)（未執筆）に譲ります。

`mc-sim/application/*.ts` は実際に Effect ベースのサービスです（`entity-manager.ts`, `player-service.ts`,
`time-service.ts`, `crop-service.ts`, `statistics-service.ts`, `settings-service.ts`, `autosave.ts`,
`inventory-service.ts`, `vitals-service.ts`, `weather-service.ts`, `equipment-service.ts`,
`game-loop.ts`）。`mc-sim/docs/responsibility.md` の該当行はどれも「実装済 `domain/xxx.ts` /
`application/xxx-service.ts`」という対で記述されており（例: :22, :23, :25）、
「状態と純粋な遷移関数は `domain/`、それを Port 経由で駆動する Effect サービスは `application/`」
という対応が一貫しています。

## 4. 命名規約

### branded type

`mc-kernel/domain/identifiers.ts` を実読しました。`WorldId` と `StageId` はいずれも同じ型で、

```ts
export type WorldId = string & Brand.Brand<'WorldId'>

export const WorldId = Brand.refined<WorldId>(
  (value) => value.trim().length > 0,
  (value) => Brand.error(`WorldId must be a non-blank string, received ${JSON.stringify(value)}`),
)
```

という形（:13-18）です。`StageId`（:30-35）も同型の構造で「非空・非空白文字列」を保証します。
新しい ID 型を作る場合はこの形（`type X = Primitive & Brand.Brand<'X'>` + `Brand.refined` で妥当性を
コンストラクタに埋め込む）に揃えてください。`mc-worldgen/domain/kernel-vocabulary.ts:121-125` の
`BlockAxis` も同じパターンです。

`StageId` にはさらに命名規約があり、コメント（`identifiers.ts:26`）にこう書かれています。

> Convention: `<owning-repo-suffix>:<stage>` — e.g. `sim:tick`, `render:draw`.

実際の使用例は `mc-sim/stages/stage-ids.ts:86` の `physics: StageId('sim:physics')` です。
`mc-sim/docs/responsibility.md` §2.1 によれば、この stage は mx-gameplay・mx-redstone・mx-ui・mc-render
の4リポジトリから `after: [StageId('sim:physics')]` として名指しされる、ロスター中で唯一のリポジトリ間
順序エッジであり、この命名規約はリポジトリを跨いで文字列だけで安全に合意するための取り決めです。

### ファイル名は kebab-case

`mc-kernel/domain/`（`block-support.ts`, `block-registry-data.ts`, `block-capabilities.ts` 等17ファイル）と
`mc-sim/domain,application/`（`vitals-hunger.ts`, `camera-pose.ts`, `entity-manager.ts`, `time-service.ts` 等
32ファイル）を実際に列挙し、すべて kebab-case であることを確認しました。例外に見えるのは
`playwright.config.ts` / `vitest.config.ts` / `vite.config.ts`（mx-ui）ですが、これらはツールが要求する
既定ファイル名であり、kebab-case 規約から外れるものではありません（`config` サフィックス自体が
kebab-case の一部として扱われます）。

### パッケージ名

`package.json#name` は `@nerima-games/<repo-name>`（例: `mc-kernel/package.json:2`
`"name": "@nerima-games/mc-kernel"`）で、リポジトリ名とスコープ付きパッケージ名を一致させています。

## 5. コミット規約

`mc-kernel` と `mx-ui` で `git log --oneline -30` を実行し、実際のコミット履歴を確認しました。

`mc-kernel`（抜粋）:
```
1450455 feat: add sword item types
5d2bcec feat: add bow and arrow item vocabulary
c93bba3 chore: modernize toolchain and test layout
a0662ff fix: two mirrors were inventing symbols their sources never had
```

`mx-ui`（抜粋）:
```
015f311 feat: add chest storage view
16f8171 fix: expose accessible mining progress
c7a2849 chore: release mx-ui 0.2.2
87eacaf fix(test): carry a ClockPort now, so the repoint day costs nothing
036c519 test: assertions whose shape could not see the claim their name made
```

両リポジトリとも `<type>: <subject>` または `<type>(<scope>): <subject>` という Conventional Commits の
型が直近30件でほぼ一貫しています。観測された `type` は `feat` `fix` `chore` `test` の4種、`scope` の例は
`fix(test): ...`（mx-ui, `87eacaf` `4d467da`）です。`subject` は英語の記述文（命令形ではなく「何が起きたか」
を説明する文体、例: `mx-ui c7a2849` を除く多くのコミットで見られる）で、末尾に句点を置かない点も
nerima-lisp の規約と共通です。破壊的変更を示す `!` や `BREAKING CHANGE:` の使用は今回の30件には
現れなかったため、その運用は [PACKAGE_STANDARD.md](PACKAGE_STANDARD.md) のバージョニング規約
（未執筆）に譲ります。

新しいリポジトリでは `<type>(<scope>): <subject>` の型に揃え、`type` は少なくとも
`feat` `fix` `chore` `test` を使い分けてください。`docs` `refactor` `perf` `ci` `build` `revert` は
必要になった時点で追加して構いません（禁止するものではなく、実測でまだ登場していないだけです）。

## 6. この文書のスコープ外

以下は意図的にこの文書に含めていません。重複を避けるため、別文書を参照してください。

- **API 設計**（REST/GraphQL のエンドポイント設計、リクエスト/レスポンスの一貫性、OpenAPI）→ [API_STANDARD.md](API_STANDARD.md)（未執筆）
- **テスト規約**（テストファイル名、カバレッジ基準、テスト基盤の選定）→ [TEST_STANDARD.md](TEST_STANDARD.md)（未執筆）
- **リポジトリ間依存の許可リスト**、および `.oxlintrc.json` の `no-restricted-imports` 節の具体的な中身
  → [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md)（未執筆）
- **パッケージ構造**（`application/` を持つかどうかの判断基準、ディレクトリの外形全般）
  → [PACKAGE_STANDARD.md](PACKAGE_STANDARD.md)（未執筆）

## この規約が機械強制されない範囲

oxlint と tsconfig のルール（§1, §2）、ファイル名の kebab-case（§4）はある程度機械的に検査可能です
（`no-restricted-imports` は現状 inert なものを含むため §1 の注記を参照）。一方で次は機械では判定できず、
レビューで見る必要があります。

- `domain/` に I/O やビジネスルールが紛れ込んでいないか（Port の型定義との区別を含む、§3）
- branded type のコンストラクタが妥当な refinement を持っているか（§4）
- StageId の命名規約 `<repo接尾辞>:<stage>` が守られているか（§4）
- コミットメッセージの `type` 選択が実態と合っているか（§5）

判定できないからといって任意ではありません。判定できないものこそ、書いておかないと揃わない部分です。
