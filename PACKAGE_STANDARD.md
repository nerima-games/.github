# nerima-games パッケージ標準

nerima-games org の全16リポジトリが従う構成基準です。
対象は TypeScript / Effect-ts で書かれた Minecraft クローン再実装で、pnpm workspaces + Nix
(flake.nix / devenv / direnv) + oxlint + vitest を共通の土台とします。
リポジトリは `mc-audio` `mc-compose` `mc-dev-meta` `mc-kernel` `mc-meshing` `mc-noise`
`mc-physics` `mc-playground-kit` `mc-render` `mc-save` `mc-sim` `mc-worldgen` `mx-gameplay`
`mx-multiplayer` `mx-redstone` `mx-ui` の16個です。

この文書は **`src/` 再構成後、かつ Wave 0 の dist 公開形への移行後の目標状態** を記述します。

`src/` 再構成(旧・移行手順1)自体は 2026-08-30 時点で16リポジトリ全部が完了しています。
残る移行対象は公開形(`package.json` の `main` / `exports["."]` / `files` / ビルド手段)です。
`mc-kernel` `mc-audio` `mc-meshing` `mc-noise` `mc-physics` `mc-playground-kit` `mc-render`
`mc-save` `mc-sim` `mc-worldgen` の10リポジトリは既に `main`/`exports["."]` が `./dist/...`
を指す形に到達していますが、そのビルド手段は不統一です(`mc-kernel` `mc-audio` `mc-noise`
`mc-save` は `tsc -p tsconfig.release.json` の単一ステップ、`mc-render` `mc-playground-kit`
は esbuild バンドルを併用、`mc-sim` は tsdown、`mc-worldgen` は `tsx scripts/build-package.ts`
を経由するなど)。`mc-compose` `mx-gameplay` `mx-multiplayer` `mx-redstone` `mx-ui` の5リポジトリ
は `main`/`exports["."]` がまだ `./src/index.ts` を指す旧形のままです(`mc-compose` は
下記「`package.json` の必須フィールドとスクリプト」節の通り今後もこの形を維持する
恒久的な例外、残り4つは移行対象)。本書「`package.json` の
必須フィールドとスクリプト」節が定める dist 形・`tsc -p tsconfig.release.json` 単一ビルドが、
これらのリポジトリが揃って到達すべき唯一の形です。

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
2026-08-30 時点で `mx-gameplay` のみがまだ `api-lock.md` を保持しており、これは移行の対象であり、
保持すべき現状ではありません。他15リポジトリは既に削除済みです。`scripts/api-lock.ts`
はどのリポジトリにも残っていません。

## `scripts/check-dependency-whitelist.ts` の廃止

2026-08-30 時点で `mc-audio` と `mx-gameplay` の2リポジトリがまだこのファイルを保持しており、
移行対象です。他14リポジトリは既に削除済みです。

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

## oxlint は `package.json` の devDependency ではなく Nix 提供(2026-08-01 追加)

上記の `no-restricted-imports` 移行作業で、oxlint のバージョンが16リポジトリ間で
サイレントに分裂していたことが判明しました(一部は `^1.76.0`、一部は `^0.12.0` — 後者には
`no-restricted-imports` 自体が実装されておらず、ファイル名を直しても機能しません)。
これを受けて oxlint は **`package.json` の devDependency から削除し、`flake.nix` の
devShell に `pkgs.oxlint` として一本化**します(nixpkgs は本書執筆時点で 1.75.0 を配布)。
CI も `.github/actions/nix-setup/`(`templates/actions/nix-setup/` からコピー)経由で
Nix をインストールしてから `nix develop --command pnpm lint` を実行し、ローカルと CI で
同じ oxlint バイナリを使う一本化を徹底します。SHA固定とCachixの詳細は
[SUPPLY_CHAIN.md「追加された信頼済みプロバイダ」](SUPPLY_CHAIN.md#追加された信頼済みプロバイダ-nix--cachix2026-08-01)を参照してください。

## `package.json` の必須フィールドとスクリプト

`src/` 再構成は全16リポジトリで完了済みです(前節参照)。ここからは Wave 0 が定める
**dist 公開形**への移行を扱います。ソースは引き続き `src/` の下に置きますが、公開されるのは
`src/` 自体ではなく、`tsc -p tsconfig.release.json` が `src/` から emit する `dist/` です。
`mc-kernel/package.json`(0.5.0、既に dist 形に到達済み)を基準形として値を示します。

| フィールド | 直接公開形(`mc-compose` など、移行対象) | dist 公開形(目標。全リポジトリ共通の書式) |
|---|---|---|
| `main` | `"./src/index.ts"` | `"./dist/index.js"` |
| `types` | `"./src/index.ts"` | `"./dist/index.d.ts"` |
| `exports["."]` | `"./src/index.ts"`(文字列) | `{ "types": "./dist/index.d.ts", "import": "./dist/index.js", "default": "./dist/index.js" }`(オブジェクト) |
| `exports["./<sub>"]` | (通常持たない) | `docs/public-api.md` が公開契約と宣言したモジュールだけ、同じ形で `./dist/<sub>.js` / `.d.ts` を指す。サブパスを増やす基準は本書ではなく `docs/public-api.md` が持つ |
| `files` | `["src", "tsconfig.base.json", "LICENSE", "README.md"]` | `["dist", "LICENSE", "README.md"]`(kernel のみ他リポジトリが `extends` する `"tsconfig.base.json"` を追加) |
| `publishConfig.access` | `"restricted"` | `"public"`(RELEASE_STANDARD.md §2。2026-08-08 に全パッケージを public 化済みで、`restricted` のままだと新規 publish が private に戻り下流 CI が 403 になる) |

`main`/`exports["."]` が `./dist/...` を指すのに対し、`oxlint` の対象パスと
`tsconfig.build.json`/`tsconfig.test.json` の `include` は引き続き `src`(と `test` `scripts`)
を指します。「配布物」と「lint/型検査の対象」は別の問いであり、dist 化によって後者が
変わるわけではありません。

`scripts` は次の10個に統一します(存在するディレクトリだけ列挙。`apps/` を持つリポジトリは
`typecheck` に `tsconfig.preview.json` の型検査を追加し、`lint`/`lint:fix` の対象パスに
`apps` を、`mx-ui` のように `test-browser/` を持つ場合はさらに `test-browser` を加えます):

```jsonc
{
  "scripts": {
    "typecheck": "tsc -p tsconfig.build.json --pretty false && tsc -p tsconfig.test.json --pretty false",
    "build": "node scripts/clean-dist.mjs && tsc -p tsconfig.release.json --pretty false",
    "lint": "oxlint --deny-warnings src test scripts apps && ast-grep scan",
    "lint:fix": "oxlint --fix src test scripts apps",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "verify": "pnpm typecheck && pnpm lint && pnpm test",
    "package:verify": "pnpm build && node scripts/verify-package.mjs",
    "prepublishOnly": "pnpm verify && pnpm package:verify"
  }
}
```

`build` が `tsc -p tsconfig.release.json` の単一ステップである点が重要です。esbuild / tsdown
によるバンドルは**廃止**します。理由: バンドルは `exports` サブパスと declaration map(型定義が
どのソースファイルに対応するかの対応表)を壊し、`mirror`/`repoint` ゲートが型の同一性を
検証できなくなります。`scripts/clean-dist.mjs`(`dist/` を消すだけ)と
`scripts/verify-package.mjs`(publish される tarball の中身を実際に検証する)は
`mc-kernel/scripts/` からコピーします。`pretest`/`pretest:coverage` のような
「test の前に毎回 build する」フックは削除し、dist に対する検証は `package:verify` の役目に
一本化します。

`verify` から `check:deps` と `api:check` を外すのは、それぞれの裏付けとなるスクリプト
(`scripts/check-dependency-whitelist.ts` と `scripts/api-lock.ts`)自体を廃止するためであり、
省略ではありません。`test:coverage` も `verify` には含めません(TEST_STANDARD.md §1 参照)。

**`mc-compose` は上記 dist 公開形の例外です**。compose を import する下流リポジトリが
存在せず、配布物は `vite build` が生成する web バンドルであるため、`main`/`exports["."]` は
`./src/index.ts` のまま維持し、`package:verify`(dist の中身検証)を持ちません。この例外は
compose 1件に限定され、他のリポジトリへ緩和として広げないでください
(`CONFORMANCE.md` §4 が compose 用に別条件として明示的にコード化しています)。

## 必須 tsconfig ファイル

`mc-kernel` (Tier1、`application/` `stages/` `apps/` いずれもなし)を基準形として、
以下6ファイルを全リポジトリに必須とします。dist 公開形への移行に伴い、
「配布物への型検査(check-only)」を担う `tsconfig.build.json` と、
「実際に `dist/` へ emit するビルド」を担う `tsconfig.release.json` を分けて持つ点が
`src/` 再構成時点からの追加点です。

| ファイル | 役割 | `include` |
|---|---|---|
| `tsconfig.base.json` | 全 tsconfig 共通のコンパイラオプション。`strict: true` に加えて全strictnessフラグを明示 | (自身は `include` を持たない) |
| `tsconfig.json` | エディタ/言語サーバ既定。リポジトリ全体を対象 | `src/**/*.ts`, `test/**/*.ts`, `scripts/**/*.ts`, `vitest.config.ts`(+ `apps/**/*.ts` があれば) |
| `tsconfig.build.json` | 配布物の型検査(`noEmit`、CIゲート)。`pnpm typecheck` から呼ばれる | `src/index.ts`, `src/domain/**/*.ts`(+ `src/application/**/*.ts`, `src/stages/**/*.ts` があれば) |
| `tsconfig.release.json` | 実際に `dist/` へ emit するビルド本体。`extends: "./tsconfig.base.json"`、`noEmit: false`、`rootDir: "src"`、`outDir: "dist"`。`include`/`exclude` は `tsconfig.build.json` と同じ対象に加え、`test/**` `scripts/**` `**/*.test.ts` `**/*.spec.ts` を明示的に `exclude`。`pnpm build` から呼ばれる | `src/index.ts`, `src/domain/**/*.ts`(+ `src/application/**/*.ts`, `src/stages/**/*.ts` があれば) |
| `tsconfig.test.json` | テストと開発ツールの型検査。`types: ["node"]` はここだけで有効 | `src/**/*.ts`, `test/**/*.ts`, `scripts/**/*.ts`, `vitest.config.ts` |
| `tsconfig.preview.json` | [条件付き] `apps/` がある場合のみ | `apps/**/*.ts`, `src/**/*.ts` |

`tsconfig.build.json` と `tsconfig.release.json` の `include` は同じ対象を指しますが、役割は
異なります。前者は型を検査するだけで何も出力しない(`pnpm typecheck` の一部として、変更を
保存するたびに実行しても壊れない速さのゲート)。後者は実際に `dist/*.js` / `dist/*.d.ts` を
書き出す(`pnpm build` / `pnpm package:verify` からのみ呼ばれる、公開物を作る側の設定)。
1つの `tsconfig` に両方の役目を持たせない(`noEmit` の値で分岐させたりしない)のは、
「型検査だけ通したいエディタ操作」と「実際に配布物を作る操作」を誤って混同しないためです。

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

`mc-kernel/vitest.config.ts` は `thresholds: { branches: 100, functions: 100, lines: 100,
statements: 100 }` を有効化していますが、これは各リポジトリの完成度に応じた個別判断であり、
本書が規定する対象ではありません(閾値そのものは `TEST_STANDARD.md` §3 が組織決定として定め、
各リポジトリでの有効化状況は `docs/testing.md` で個別に扱います)。

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
`oxlint` の対象は `src` 一語、`tsconfig.build.json`/`tsconfig.release.json` の `include` は
`src/**/*.ts` の一語で表現できます(条件付きディレクトリの粒度を保つために本書では
`src/index.ts` `src/domain/**/*.ts` のように書き分けていますが、「lint/型検査の対象は `src/`
の内か外か」という1つの問いに単純化される点は変わりません)。
`apps/` を `src/` の外に置くのは、この「lint/型検査の対象は `src/` の中」という単純な境界を
守るためで、プレビュー/デモのエントリは配布物ではないので `src/` の中に紛れ込ませません。

**この境界は「lint/型検査の対象」の話であり、「`npm publish` される `files`」の話ではありません
(2026-08-30 追記)。** `src/` 再構成が定めた時点では両者は一致していました(`files: ["src", ...]`)。
Wave 0 の dist 公開形移行後は、`tsc -p tsconfig.release.json` が `src/` から `dist/` へ emit し、
`files` は `["dist", "LICENSE", "README.md"]`(公開される物)を指す一方、`oxlint`/
`tsconfig.build.json`/`tsconfig.release.json` の対象は引き続き `src`(検査される物)を指します。
「配布物と非配布物の境界」は今も `src/` の内か外かで単純化されたままですが、「公開される
バイト列そのもの」は `src/` ではなく、そこから生成される `dist/` になった、という区別です。

## この文書の適用範囲

本書はリポジトリの外形(ディレクトリ構成、`package.json` の該当フィールド、`tsconfig.*.json`
の構成、`vitest.config.ts` の `coverage.include`)を規定します。
ドキュメントページの内容そのもの(各 `docs/*.md` に何を書くか)は別文書
(`DOCS_STANDARD.md`、本 org リポジトリに別途作成)を参照してください。
