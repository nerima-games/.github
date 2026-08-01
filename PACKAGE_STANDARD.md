# nerima-games パッケージ標準

nerima-games org の全16リポジトリが従う構成基準です。
対象は TypeScript / Effect-ts で書かれた Minecraft クローン再実装で、pnpm workspaces + Nix
(flake.nix / devenv / direnv) + oxlint + vitest を共通の土台とします。
リポジトリは `mc-audio` `mc-compose` `mc-dev-meta` `mc-kernel` `mc-meshing` `mc-noise`
`mc-physics` `mc-playground-kit` `mc-render` `mc-save` `mc-sim` `mc-worldgen` `mx-gameplay`
`mx-multiplayer` `mx-redstone` `mx-ui` の16個です。

この文書は **`src/` 再構成後の目標状態** を記述します。
現時点でこの形になっているリポジトリはまだ存在しません。
たとえば `mc-kernel` は本書執筆時点で `index.ts` / `domain/` がリポジトリ直下に置かれており
(`src/` を経由していません)、`mc-render` と `mx-ui` も同様に `application/` `stages/` が
直下にあります。この文書はそれらを `src/` 配下へ寄せるための、移行先の仕様書です。

## 4層の依存アーキテクチャ

層の番号は下ほど基盤に近く、依存は同じ層か下の層へのみ向きます。

| 層 | 役割 | 所属 |
|---|---|---|
| Tier1 | 安定ライブラリ。org内依存ゼロ | `mc-kernel` `mc-noise` `mc-meshing` `mc-physics` `mc-save` `mc-audio` |
| Tier2 | 基盤モジュール | `mc-worldgen` `mc-sim` `mc-render` `mc-playground-kit` |
| Tier3 | 体験モジュール。この4つの間に横の依存を持たない | `mx-gameplay` `mx-redstone` `mx-ui` `mx-multiplayer` |
| Tier4 | 合成 | `mc-compose` |
| 層外 | pnpm workspace の開発ツール束ね役。依存グラフの外 | `mc-dev-meta` |

`mc-kernel/package.json` の `dependencies` は `effect` のみで、これが Tier1 の「org内依存ゼロ」の実例です。
一方 `mc-render/package.json` は `@nerima-games/mc-kernel` `@nerima-games/mc-meshing`
`@nerima-games/mc-worldgen` を持ち、Tier2 が Tier1 に依存する形を示します。
層とディレクトリ構成の間には相関はあっても因果はありません。次節の3つの条件軸のほうが実体です。

## ディレクトリツリー(目標状態)

```
<repo>/
├── src/
│   ├── index.ts            # 公開バレル。旧 index.ts の移設先
│   ├── domain/              # 純粋な型・関数。I/O なし
│   ├── application/         # [条件付き] ステートフルな Effect サービス/Port を持つ場合のみ
│   └── stages/               # [条件付き] 共有フレームパイプラインの StageId に参加する場合のみ
├── apps/                     # [条件付き] プレビュー/デモ実行エントリがある場合のみ。src/ の外、リポジトリ直下
│   └── <app-name>/
├── test/                     # src/ と並ぶ直下のきょうだい。フラットが既定
│   ├── support/                # [任意] mx-gameplay 方式: 共有テストダブル
│   └── fixtures/               # [任意] mx-ui 方式: 共有フィクスチャ
├── test-browser/              # [条件付き] mx-ui のみ: 実ブラウザ DOM/E2E テスト
├── scripts/                    # src/ と並ぶ直下のきょうだい
├── docs/
│   ├── README.md
│   ├── architecture.md
│   ├── responsibility.md
│   ├── public-api.md
│   ├── testing.md
│   ├── versioning.md
│   ├── design-notes.md
│   └── porting.md            # [条件付き]。必須ページの詳細は DOCS_STANDARD.md を参照
├── package.json
├── tsconfig.base.json
├── tsconfig.json
├── tsconfig.build.json
├── tsconfig.test.json
├── tsconfig.preview.json      # [条件付き] apps/ がある場合のみ
├── playwright.config.ts       # [条件付き] mx-ui のみ
├── .oxlintrc.json
├── vitest.config.ts
├── flake.nix
├── flake.lock
├── .envrc
├── .gitignore
├── .npmrc
├── LICENSE
├── README.md
├── pnpm-lock.yaml
└── pnpm-workspace.yaml
```

**`apps/` は `src/` の外、リポジトリ直下のきょうだいです。** `src/` の中には入れません。
プレビュー/デモの実行エントリは配布されるライブラリコードではなく、`tsconfig.preview.json` が
証明する「配布物は DOM/three に依存しない」という主張の対象外に置くための切り分けです
(根拠は次節「なぜ `src/` か」を参照)。

`test/` と `scripts/` は今回の再構成でも位置を変えません。`src/` と同じ階層の直下に残ります。
`test/` はフラットが既定ですが、共有テストダブルやフィクスチャを置く場合は `test/support/`
(`mx-gameplay/test/support/` に `chunk-store-double.ts` `entity-manager-double.ts`
`frame-runner.ts` `frame-services.ts` `inventory-service-double.ts`
`player-service-double.ts` の実例があります)または `test/fixtures/`
(`mx-ui/test/fixtures/` `mc-render/test/fixtures/` に実例があります)を作ってよい、という任意のサブディレクトリです。

## 3つの独立した条件軸

**「Tier が上がるほどディレクトリが増える」というモデルではありません。**
どの層に属していても、以下の3つの yes/no 質問がリポジトリごとに独立して答えを持ち、
その答えの組み合わせだけが追加ディレクトリの有無を決めます。

| # | 質問 | Yes の場合に追加されるもの | 実例 |
|---|---|---|---|
| 1 | ステートフルな Effect サービス/Port を自分で持つか | `src/application/` | `mc-render/application/`(`world-renderer.ts` など9ファイル)、`mx-ui/application/`(`hud-view.ts` など15ファイル) |
| 2 | 共有のフレームパイプラインの StageId 順序に参加するか | `src/stages/` | `mc-render/stages/`(`registration.ts` `stage-ids.ts`)、`mx-ui/stages/`(同名2ファイル) |
| 3 | プレビュー/デモの実行可能エントリを持つか | `apps/`(`src/` の外)+ `tsconfig.preview.json` | `mc-render/apps/preview-render/`、`mx-ui/apps/preview-screens/` と `apps/browser-harness/` |
| 3-a | (`mx-ui` 固有)実ブラウザ DOM/E2E テストが必要か | `test-browser/` + `playwright.config.ts` | `mx-ui/test-browser/`(`dom-surface.spec.ts` など4 spec)、`mx-ui/playwright.config.ts` |

`mc-kernel` はこの3問すべてに No で答えるリポジトリの実例です。Tier1 最小構成として
`domain/` のみを持ち、`application/` `stages/` `apps/` のいずれも存在しません
(`mc-kernel/index.ts` のバレルは `domain/*` の re-export のみで、Port も stage 登録も含みません)。

**Tier と条件軸が相関しないことは、16リポジトリを直接 `ls` して確認済みです。**
Tier1 の中だけでも割れます。`mc-kernel` `mc-meshing` `mc-noise` `mc-physics` `mc-save` は
3問すべて No ですが、同じ Tier1 の `mc-audio` は `apps/` を持ちます
(`application/` `stages/` は No のまま)。「安定ライブラリだから何も持たない」わけではなく、
プレビュー用の実行エントリの有無は Tier1 の中でも独立に決まります。

Tier2 の4つ (`mc-worldgen` `mc-sim` `mc-render` `mc-playground-kit`) は全員が
`application/` と `apps/` を持ちますが、`stages/` は `mc-render` と `mc-sim` だけが持ち、
`mc-worldgen` と `mc-playground-kit` は持ちません。同じ Tier で同じく質問1・3に Yes と答えても、
質問2への答えは割れます。

Tier3 の4つ (`mx-gameplay` `mx-redstone` `mx-ui` `mx-multiplayer`) は全員が `apps/` と
`stages/` を持ちますが、`application/` は `mx-redstone` と `mx-ui` だけが持ち、
`mx-gameplay` と `mx-multiplayer` は持ちません。さらに `test-browser/` +
`playwright.config.ts` は `mx-ui` だけの固有装備で、同じ Tier3 の他の3つにはありません。

つまり「ステートフルな副作用を持つか」「フレーム順序に参加するか」「プレビューエントリを
持つか」は、Tier1 だろうと Tier2/3 だろうと、リポジトリごとに独立に Yes/No が決まります。
本書は判定手順ではなく、Yes と答えた場合の配置場所を規定するものなので、各リポジトリの
実装者は自リポジトリについて軸ごとに `ls application apps stages test-browser 2>/dev/null`
で確認してください。

## `api-lock.md` / `scripts/api-lock.ts` の廃止

org 標準から完全に削除します。今後どのリポジトリでも必須としません。
`mc-kernel` `mc-render` `mx-ui` は本書執筆時点でまだ `api-lock.md` と `scripts/api-lock.ts`
(および `package.json` の `api:check` / `api:update` スクリプト)を持っていますが、
これは移行の対象であり、保持すべき現状ではありません。`src/` 移行と合わせて削除してください。

## `scripts/check-dependency-whitelist.ts` の廃止

同じく org 標準から削除します。代替は各リポジトリの `.oxlintrc.json` に書く
`no-restricted-imports` ルールです。`mc-kernel/.oxlintrc.json` は既に
`no-restricted-imports` で `effect` のデフォルトインポート禁止を書いていますが
(`effect` 本体からの `default` エクスポート禁止)、これを拡張して
モジュール間の禁止importをここへ移します。**内容はリポジトリごとに違ってよく、
むしろ違うべきです。** 各リポジトリが許可された依存先も禁止パターンも異なるため、
byte-identical であることは適合の条件ではありません。`check-dependency-whitelist.ts`
が担っていた「時刻源の直接呼び出し禁止」のような oxlint のルールで表現できないチェックは、
oxlint がそのルールを実装するまでの間、当該リポジトリの `scripts/` に個別の代替スクリプトを
置くかどうかを各リポジトリの裁量とします(org 標準としては要求しません)。

## `package.json` の必須フィールドとスクリプト

`src/` 移行に伴い、以下を書き換えます。`mc-kernel/package.json` (移行前)を例に、
移行後の値を示します。

| フィールド | 移行前 (`mc-kernel` 現状) | 移行後 |
|---|---|---|
| `main` | `"./index.ts"` | `"./src/index.ts"` |
| `types` | `"./index.ts"` | `"./src/index.ts"` |
| `exports["."]` | `"./index.ts"` | `"./src/index.ts"` |
| `files` | `["index.ts", "domain", "tsconfig.base.json", "LICENSE", "README.md"]` | `["src", "tsconfig.base.json", "LICENSE", "README.md"]` |
| `scripts.lint` | `"oxlint --deny-warnings index.ts domain scripts test"` | `"oxlint --deny-warnings src scripts test"` |
| `scripts.lint:fix` | `"oxlint --fix index.ts domain scripts test"` | `"oxlint --fix src scripts test"` |
| `scripts.verify` | `"pnpm typecheck && pnpm lint && pnpm check:deps && pnpm api:check && pnpm test"` | `"pnpm typecheck && pnpm lint && pnpm test"` |

`files` は `"index.ts", "domain"` のような個別列挙をやめ、`"src"` 一語に集約します。
`application/` `stages/` を持つリポジトリでも同様に `"src"` 一語で足ります
(それらは `src/application/` `src/stages/` として `src/` の中に入るため)。

`apps/` を持つリポジトリは `scripts.typecheck` に `tsconfig.preview.json` の型検査を追加し
(`mc-render/package.json` の現状の並び `tsc -p tsconfig.build.json ... && tsc -p
tsconfig.test.json ... && tsc -p tsconfig.preview.json ...` を移行後もそのまま踏襲)、
`scripts.lint` / `scripts.lint:fix` の対象パスに `apps` を追加します。
`mx-ui` のように `test-browser/` を持つ場合はそこにも `test-browser` を追加し、
`scripts.test:browser` (`"playwright test"`) を維持します。

`verify` から `check:deps` と `api:check` を外すのは、それぞれの裏付けとなるスクリプト
(`scripts/check-dependency-whitelist.ts` と `scripts/api-lock.ts`)自体を廃止するためであり、
省略ではありません。

## 必須 tsconfig ファイル

`mc-kernel` (Tier1、`application/` `stages/` `apps/` いずれもなし)を基準形として、
以下5ファイルを全リポジトリに必須とします。

| ファイル | 役割 | `include` (移行後、`src/` 前提) |
|---|---|---|
| `tsconfig.base.json` | 全 tsconfig 共通のコンパイラオプション。`strict: true` に加えて全strictnessフラグを明示 | (自身は `include` を持たない) |
| `tsconfig.json` | エディタ/言語サーバ既定。リポジトリ全体を対象 | `src/**/*.ts`, `test/**/*.ts`, `scripts/**/*.ts`, `vitest.config.ts`(+ `apps/**/*.ts` があれば) |
| `tsconfig.build.json` | 配布物の型検査。CIゲート | `src/index.ts`, `src/domain/**/*.ts`(+ `src/application/**/*.ts`, `src/stages/**/*.ts` があれば) |
| `tsconfig.test.json` | テストと開発ツールの型検査。`types: ["node"]` はここだけで有効 | `src/**/*.ts`, `test/**/*.ts`, `scripts/**/*.ts`, `vitest.config.ts` |
| `tsconfig.preview.json` | [条件付き] `apps/` がある場合のみ | `apps/**/*.ts`, `src/**/*.ts` |

`tsconfig.base.json` の役割で特に重要なのは、`mc-kernel/tsconfig.base.json` のコメントが
明記する方針です。「`lib: ["ES2024"]` のみで DOM も WebWorker も Node globals も持たない」
ことが Tier1 ライブラリの platform-agnostic 性を機械的に保証します。DOM や three を必要とする
リポジトリ(`mc-render` など)は自分の `tsconfig.base.json` でそれを追加してよい、というのが
現状の設計です。`tsconfig.build.json` はこの `types: []` を継承したまま `src/domain/**` (と
`src/application/**` `src/stages/**`)だけを対象にすることで、「配布される本体コードに
Node型やDOM型が紛れ込んでいないか」を型検査そのものでゲートします。`mc-render/
tsconfig.build.json` のコメントが「if a Node type ever leaks into `domain/` or
`application/` this project fails」と書く通りです。

`apps/` を持つ場合の `tsconfig.preview.json` は、あえて `tsconfig.build.json` とは別の
プロジェクトにします。`mc-render/tsconfig.preview.json` のコメントが理由を明記しています。
`tsconfig.build.json` が示す「配布される本体は platform-free」という証明を壊さずに、
プレビューアプリだけに DOM や three のような preview 専用の型を足すための分離です。

`test/fixtures/**` のようにテスト内で意図的に DOM 型を使うファイルがある場合
(`mc-render/test/fixtures/`)、`tsconfig.test.json` からは除外し、別の専用テストで
`lib.dom.d.ts` に対してコンパイルします。`mc-render/tsconfig.test.json` のコメントに
「Compiling them here, where there is no DOM, would only fail; putting them in the
shipped project would be the `"DOM"` flag arriving by the back door」とある通りです。
`src/` 移行後もこの除外の考え方はそのまま踏襲します。

## `vitest.config.ts` の `coverage.include`

`src/` 移行に伴い書き換えます。

| 軸の有無 | 移行前 (`mc-kernel` 現状) | 移行後 |
|---|---|---|
| 最小 (`application/` `stages/` なし) | `['index.ts', 'domain/**/*.ts']` | `['src/index.ts', 'src/domain/**/*.ts']` |
| `application/` あり | `['index.ts', 'domain/**/*.ts', 'application/**/*.ts']`(`mc-render` 現状) | `['src/index.ts', 'src/domain/**/*.ts', 'src/application/**/*.ts']` |
| `stages/` あり | (同上に追加) | 上記に `'src/stages/**/*.ts'` を追加 |

`mc-kernel/vitest.config.ts` は `thresholds: { branches: 99, functions: 99, lines: 99,
statements: 99 }` を有効化していますが、これは各リポジトリの完成度に応じた個別判断であり、
本書が規定する対象ではありません(閾値の有無・値は `docs/testing.md` で個別に扱います)。

## なぜ `src/` か

現状(`mc-kernel` `mc-render` `mx-ui` いずれも)は `index.ts` と `domain/` (と該当すれば
`application/` `stages/`)がリポジトリ直下に、`test/` `scripts/` `apps/` `docs/` などの
非配布ディレクトリと同じ階層に並んでいます。これでは「配布されるコード」と
「配布されないコード」がディレクトリ階層の上では区別できず、`package.json#files` が
`"index.ts", "domain"` のように個別ファイル・ディレクトリを列挙してようやく境界を表現している
状態です。`application/` `stages/` が増えるたびに `files` 配列と `oxlint` の対象パスと
`tsconfig.build.json` の `include` の3箇所を同時に更新する必要があり、更新漏れは
「配布物に含まれるべきでないものが `npm publish` される」または「ドメイン層が lint/型検査を
すり抜ける」という2方向の事故につながります。

`src/` の下に配布対象(`index.ts` `domain/` `application/` `stages/`)をすべて集約すると、
`files` は `"src"` の一語で済み、`oxlint` の対象は `src` 一語、`tsconfig.build.json` の
`include` は `src/**/*.ts` の一語で表現できます(条件付きディレクトリの粒度を保つために
本書では `src/index.ts` `src/domain/**/*.ts` のように書き分けていますが、境界が
「`src/` の内か外か」という1つの問いに単純化される点は変わりません)。
`apps/` を `src/` の外に置くのは、この「配布対象は `src/` の中」という単純な境界を守るためで、
プレビュー/デモのエントリは配布物ではないので `src/` の中に紛れ込ませません。

## この文書の適用範囲

本書はリポジトリの外形(ディレクトリ構成、`package.json` の該当フィールド、`tsconfig.*.json`
の構成、`vitest.config.ts` の `coverage.include`)を規定します。
ドキュメントページの内容そのもの(各 `docs/*.md` に何を書くか)は別文書
(`DOCS_STANDARD.md`、本 org リポジトリに別途作成)を参照してください。
