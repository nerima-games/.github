# nerima-games 用語集

nerima-games org（16リポジトリ、TypeScript / Effect-ts による Minecraft クローン再実装）で使う語を統一する。
[PACKAGE_STANDARD.md](PACKAGE_STANDARD.md) がリポジトリの外形を、[CODING_STANDARD.md](CODING_STANDARD.md) がコードの中身を決めるのに対し、
この文書は org 全体で使う語そのものを決める。GLOSSARY.md も DECISIONS.md も、この org でこれまで存在しなかった文書であり、
今回新規に書き起こす。

対象は2種類ある。

- **識別子語彙**: `mc-kernel` が定義し、全リポジトリが読み書きする branded type、Port、フレーム合成の用語（第1部）。
- **日本語表記の統一**: `docs/*.md` が実際に使っている日本語の技術用語のうち、複数リポジトリで一貫して使われているもの（第2部）。

「定義は `<file>` に正典がある」という形で、各語の一次資料を示す。この文書は語の意味を要約するだけで、
実装そのものはリンク先が持つ。

---

# 第1部: 識別子語彙

## branded type（ブランデッド型）

`effect` の `Brand` を使い、実体は `string` / `number` だが取り違えると事故になる値を型で区別する仕組み。
`mc-kernel/domain/identifiers.ts` と `mc-kernel/domain/coordinates.ts` が規範形であり、型と同名の値コンストラクタを
export する（`type WorldId` と `const WorldId`）。定義は [API_STANDARD.md「ブランデッド型（Brand）」](API_STANDARD.md#2-1-ブランデッド型brand)を参照。

| 用語 | 定義 | 定義の正典 |
|---|---|---|
| `WorldId` | 1つのワールド（セーブデータ）を指す識別子。非空文字列であることだけを検証する。kernel はワールドがどう永続化されるかを知らない | `mc-kernel/domain/identifiers.ts` |
| `StageId` | フレームステージ（1フレーム内の1単位の処理）を指す識別子。非空文字列。慣習は `<所有リポジトリの接尾辞>:<ステージ名>`（例: `sim:tick`、`render:draw`）だが機械強制はされていない | `mc-kernel/domain/identifiers.ts`（`mc-compose/domain/stage-order.ts` が同一定義をローカル複製） |
| `BlockAxis` | 整数のワールド空間ブロック座標。1軸ぶん。`Number.isSafeInteger` を満たす | `mc-kernel/domain/coordinates.ts` |
| `ChunkAxis` | 整数のチャンク空間座標。1軸ぶん。1刻みが `CHUNK_SIZE_XZ`(16)ブロックに対応する | `mc-kernel/domain/coordinates.ts` |
| `LocalAxis` | チャンクローカルな水平座標。`[0, CHUNK_SIZE_XZ - 1]` の整数に限定される | `mc-kernel/domain/coordinates.ts` |
| `Position` | 連続値のワールド空間の点（x, y, z）。Y軸が上 | `mc-kernel/domain/coordinates.ts` |
| `BlockPosition` | 整数のワールド空間ブロックセル。各成分が `BlockAxis` | `mc-kernel/domain/coordinates.ts` |
| `ChunkCoord` | チャンク列の水平アドレス（`cx`, `cz`）。各成分が `ChunkAxis` | `mc-kernel/domain/coordinates.ts` |
| `LocalBlockCoord` | チャンクに対する相対ブロックアドレス（`lx`, `ly`, `lz`）。`lx`/`lz` は `LocalAxis`、`ly` は素の `BlockAxis`（垂直方向はワールド生成の関心事であり kernel が所有しない） | `mc-kernel/domain/coordinates.ts` |
| `AABB` | 連続空間の軸並行境界ボックス。`aabb` コンストラクタが `min <= max` を成分ごとに正規化する。接触面（面が一致するだけ）は交差とみなさない（`aabbIntersects`） | `mc-kernel/domain/coordinates.ts` |

## Port / Context.Tag

サービス境界（時計、プレイヤー状態、チャンクストアなど）を宣言するための Effect の型。定義は
[API_STANDARD.md「Effect Context.Tag による Port」](API_STANDARD.md#2-4-effect-contexttag-による-port)を参照。

| 用語 | 定義 | 定義の正典 |
|---|---|---|
| Port | `Context.Tag` として宣言されるサービス境界。Tag 識別子文字列はフルパッケージ名を含める（例: `'@nerima-games/mc-kernel/ClockPort'`）。これは実行時の Layer 解決の契約そのものであり、TypeScript の型検査では変更を検出できない | `mc-kernel/domain/clock.ts` |
| `ClockPort` | 単調時刻(`monotonicSecs`)と壁時計時刻(`wallClockEpochMillis`)を提供する Port。ヴァーティカルスライスのスパイクで、`FrameServices` に生き残った唯一の要求がこれだった | `mc-kernel/domain/clock.ts` |
| Port の実装 | Port を定義したリポジトリには置かない。kernel は決定的なテスト用実装（`FixedClockLayer`）だけを持ち、実クロックを読むアダプタは利用側リポジトリが注入する | `mc-kernel/domain/clock.ts`、[API_STANDARD.md §2-4](API_STANDARD.md#2-4-effect-contexttag-による-port) |

## フレーム合成語彙（`mc-kernel/domain/frame.ts`, `mc-compose/domain/stage-order.ts`）

「フレーム」とは、ホストリポジトリ（`mc-compose`）が全モジュールの `GameModule` を合成して作る1フレームぶんの
処理列を指す。どのリポジトリもグローバルなステージ順序を知らない、というのがこの語彙群の設計原則
（plan.md §2.3-3「stage 実行順序表は compose が唯一所有」）。

| 用語 | 定義 | 定義の正典 |
|---|---|---|
| `FrameServices` | 全フレームステージが前提してよい実行文脈。SETTLED（確定済み）で `ClockPort` のみ。ヴァーティカルスライスのスパイクで測定した結果、他の候補サービスはすべて「登録時に一度取得すれば残余要求がない」形だったのに対し、時刻だけが「呼び出しの都度、メソッドレベルで要求される」形だった | `mc-kernel/domain/frame.ts` |
| `StageRegistration` | 1つのリポジトリが1フレームに提供する1単位の処理。`id`(`StageId`)、`after`(順序制約。存在しないステージを指しても構わない = dangling edge)、`run`(`Effect<void, never, FrameServices>` を返す関数)を持つ | `mc-kernel/domain/frame.ts` |
| `GameModule` | 1つのリポジトリがゲームに提供する全体。`layers`(提供する Effect Layer)と `frameStages`(登録するステージの `Effect`)を持つ。`frameStages` が値ではなく `Effect` である理由は、ステージの構築（サービスの取得）と実行を分離するため | `mc-kernel/domain/frame.ts` |
| `after` エッジ / dangling edge | `StageRegistration.after` が指す順序制約。指し先のステージがそのビルドに存在しない場合は「dangling」と呼び、エラーにはせず単に無視したうえで報告する。これは「入力があるなら入力の後に走る」という慣用句を表現する正規の手段であり、同時に typo とも区別が付かない | `mc-compose/domain/stage-order.ts` |
| `StageId` の namespace / name | `<namespace>:<name>` の形式のうち、コロン以前を namespace、最後のコロン以降を name と呼ぶ。`StagePhase.members` の照合単位になる（`redstone:` は namespace 全体に、`physics` は name に一致する） | `mc-compose/domain/stage-order.ts` |
| `StagePhase` / skeleton | フレームの「標準ステージ骨格」(plan.md §4.2)。フェーズの並び順が、実際に登録されたステージ間の暗黙の順序制約とタイブレークの根拠になる。骨格に存在しないステージは `unmatchedPhase` として報告され、最後尾に置かれる（modding には正規の形。typo とは症状が区別できない） | `mc-compose/domain/stage-order.ts` |
| `StageOrderPlan` | `resolveStageOrder` の出力。単一の全順序 `order`、無視された `dangling` エッジの一覧、骨格のどのフェーズにも一致しなかった `unmatchedPhase` の一覧を持つ | `mc-compose/domain/stage-order.ts` |

## Tier1〜Tier4 と「層外」

4層の依存アーキテクチャを表す語。層の番号は下ほど基盤に近く、依存は同じ層か下の層へのみ向く。
定義は [PACKAGE_STANDARD.md「4層の依存アーキテクチャ」](PACKAGE_STANDARD.md#4層の依存アーキテクチャ)を参照。

| 用語 | 定義 | 所属リポジトリ |
|---|---|---|
| Tier1 | 安定ライブラリ。org内依存ゼロ | `mc-kernel` `mc-noise` `mc-meshing` `mc-physics` `mc-save` `mc-audio` |
| Tier2 | 基盤モジュール | `mc-worldgen` `mc-sim` `mc-render` `mc-playground-kit` |
| Tier3 | 体験モジュール。この4つの間に横の依存を持たない | `mx-gameplay` `mx-redstone` `mx-ui` `mx-multiplayer` |
| Tier4 | 合成。全リポジトリの `GameModule` を束ねて1つの `StageOrderPlan` にする層 | `mc-compose` |
| 層外 | pnpm workspace の開発ツール束ね役。実行時の依存グラフには載らない | `mc-dev-meta` |

**層とディレクトリ構成の間には相関はあっても因果はない。** どのリポジトリが `src/application/` や
`src/stages/` を持つかは Tier では決まらず、3つの独立した条件軸（ステートフルな Port を持つか、
共有フレームパイプラインに参加するか、プレビュー/デモの実行エントリを持つか）で決まる
（詳細は [PACKAGE_STANDARD.md「3つの独立した条件軸」](PACKAGE_STANDARD.md#3つの独立した条件軸)）。

## 「宣言された」依存グラフ vs 「観測された」依存グラフ

今回の org 標準化作業で発見された区別。**「Tier モデルとして文書に書かれている依存グラフ」と
「各リポジトリの `package.json` の `dependencies` を実際に読んで得られる依存グラフ」は、別物として扱う必要がある。**
理由は、この2つが一致するかどうかは主張するだけでは確認できず、`package.json` を実際に開いて読む以外に
検証手段がないためである。

| 用語 | 定義 |
|---|---|
| 宣言された依存グラフ | `PACKAGE_STANDARD.md` の Tier 表のように、文書として「こうあるべき」と書かれている依存の向き |
| 観測された依存グラフ | 各リポジトリの `package.json` の `dependencies` フィールドを実際に読んで得られる、コードが実際にビルド時・実行時にインポートしている依存の向き |

`mc-kernel/package.json` の `dependencies` が `effect` のみであることは、Tier1「org内依存ゼロ」の**観測された**実例である。
`mc-render/package.json` が `@nerima-games/mc-kernel` `@nerima-games/mc-meshing` `@nerima-games/mc-worldgen` を持つことは、
Tier2 が Tier1 に依存するという**宣言**を**観測**が裏付けている実例である。この2つが一致しているかどうかを
検証すること自体が、標準を書く作業の一部である。定義の正典は [PACKAGE_STANDARD.md「4層の依存アーキテクチャ」](PACKAGE_STANDARD.md#4層の依存アーキテクチャ)。

---

# 第2部: 日本語表記の統一

`docs/*.md` は日本語で書く（[DOCS_STANDARD.md §6](DOCS_STANDARD.md#6-執筆言語)）。以下は複数リポジトリの
`docs/architecture.md` `docs/responsibility.md` などで一貫して使われている語のうち、統一の価値があるものを
数えて挙げる。出現数は `*/docs/*.md`（node_modules・worktrees を除く）から数えた、その語を含むファイル数。

| 用語 | 定義 | 出現(ファイル数) | 定義の正典 |
|---|---|---|---|
| 責務 | あるリポジトリ・モジュールが何を所有するか。`responsibility.md` の第1節の見出しが必ずこれになる | 61 | 各リポジトリの `docs/responsibility.md`（[DOCS_STANDARD.md §3-3](DOCS_STANDARD.md#3-3-responsibilitymd)） |
| 非スコープ（明示） | 「持ってはならないもの」を項目立てて列挙し、なぜ持たないか・どこが持つかを添えるセクション。`responsibility.md` の必須セクション | 20 | 各リポジトリの `docs/responsibility.md`、[DOCS_STANDARD.md §3-3](DOCS_STANDARD.md#3-3-responsibilitymd) |
| 横断 | 16リポジトリ全体、または複数リポジトリにまたがること。「横断的な設計ルール」「横断チェック」のように使う。単一リポジトリ内で閉じる話には使わない | 16 | [DOCS_STANDARD.md §3-2](DOCS_STANDARD.md#3-2-architecturemd)（`architecture.md` の必須セクション「自リポジトリに関わる横断的な設計ルール」） |
| 波及 | 基準や変更を1つ加えたときに、他のリポジトリへ作業や影響が伝わること。「影響」ではなく「波及」と書く場面で使われている | 13 | 各リポジトリの `docs/versioning.md` 等（例: 「kernel の場合その差が全リポジトリに波及する」） |
| 凍結 | 公開 API を特定のバージョン（`1.0.0` 等）で確定し、以後の変更を破壊的変更としてのみ許すこと。`mc-kernel/docs/freeze-checklist.md` が前提条件を列挙する | 59 | `mc-kernel/docs/freeze-checklist.md`、各リポジトリの `docs/versioning.md` |

上記のうち「責務」「非スコープ」「横断」は [DOCS_STANDARD.md](DOCS_STANDARD.md) が `docs/` の型として要求する
セクションの見出し語そのものであり、単なる頻出語ではなく標準の一部として固定されている。「波及」「凍結」は
型としては要求されないが、複数リポジトリの独立した執筆で綴りが割れていない語として、この文書が言葉として
明記する。

## 注記

この文書は語の**意味**を統一するものであり、各リポジトリの `docs/*.md` が書く**内容**を集約するものではない
（[DOCS_STANDARD.md §5](DOCS_STANDARD.md#5-本標準が定めないこと)と同じ立場）。新しい概念を org 標準文書に
導入するときは、この文書に定義を追加すること。追加する語の出現状況を確認せずに追加した場合、後から見たときに
なぜその語を採ったかの根拠が分からなくなる。
