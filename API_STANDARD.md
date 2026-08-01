# API 標準

nerima-games 16 リポジトリ共通の「公開 API とは何か」「どう設計するか」「何が破壊的変更か」の標準。
パッケージ構成そのもの（バレルの配置場所など）は [PACKAGE_STANDARD.md](./PACKAGE_STANDARD.md) を参照。
自己レビュー時にこの標準へどう照らすかは [REVIEW_STANDARD.md](./REVIEW_STANDARD.md) を参照。

## 1. 公開 API の定義

**公開 API とは `src/index.ts` が re-export するものだけである。** それ以外は実装詳細であり、
他リポジトリはもちろん自リポジトリ内であっても「バレル外から直接 import してよい」根拠にはならない。

判定はシンプルで機械的である。

- `src/index.ts` に `export * from './domain/...'` または個別 `export { X } from '...'` があるものは公開 API。
- `domain/` や `application/` に存在していても、バレルが re-export しなければ非公開。

mc-kernel の `index.ts`（移行後 `src/index.ts`）はこの原則をそのまま体現している。

```typescript
export * from './domain/block-capabilities'
export * from './domain/block-definition'
export * from './domain/block-harvest'
export * from './domain/block-item'
export * from './domain/block-properties'
export * from './domain/block-registry'
export * from './domain/block-support'
export * from './domain/block-type'
export * from './domain/camera'
export * from './domain/clock'
export * from './domain/coordinates'
export * from './domain/frame'
export * from './domain/identifiers'
export * from './domain/item-type'
export * from './domain/quantities'
```

一方 `mx-gameplay/index.ts` はバレルに列挙されているドメインモジュールについて、ヘッダコメントで明示的に
こう断っている。

> Its public surface is stage registration (`stages/registration.ts`). The domain modules below are
> exported because they are the units the tests and the previews drive directly, not because another
> repository is expected to import them; see docs/public-api.md for what is contract and what is merely
> visible.

**「バレルから見える」と「契約である」は同じではない。** 見えるだけの export と、他リポジトリが実際に依存する
契約は別物であり、どちらであるかをバレル自身か `docs/public-api.md` に書き分けるのは各リポジトリの責務である。
このドキュメント自身がその書き分けの模範であり、少なくとも「1 リポジトリ以上の他リポジトリが実際に import している
かどうか」を契約性の第一の判定材料にすること。

### 1-1. `export *` は約束である

`mc-sim/index.ts` のヘッダはこれを明文化している。

> The barrel is therefore deliberately narrow and deliberately explicit — `export *` from a module is a
> promise to keep everything in that module stable, and this file makes that promise only where it is
> meant.

`export *` をモジュールに書く前に、そのモジュールの中身全部を安定させる意思があるかを確認すること。
「とりあえず全部 export しておく」は禁止であり、意図的に外しているものは `mc-worldgen/index.ts` の
`Dimension` の扱いのように、コメントで理由を残す。

```typescript
// `Dimension` is published from here, and that is a DECISION rather than a
// widening. `domain/nether-travel.ts` declared the union 「PROVISIONALLY」 and
// deliberately kept it off this barrel so that no consumer could depend on the
// spelling while its owner was undecided. The owner is now decided...
```

型の綴りが決まっていない段階でバレルから外しておくのは正当な選択である。決まった時点でバレルに足すのは
加算的変更（§3-2）であり、外すこと自体は破壊的変更ではなく「まだ約束していない」という表明である。

## 2. 命名・設計規約

以下は一般論ではなく、このコードベースが実際に採用している 3 つのパターンを、実例つきで規約化したものである。

### 2-1. ブランデッド型（Brand）

識別子・数量など「実体は string/number だが取り違えると事故になる値」は `effect` の `Brand` で区別する。
`mc-kernel/domain/identifiers.ts` が規範形。

```typescript
export type WorldId = string & Brand.Brand<'WorldId'>

export const WorldId = Brand.refined<WorldId>(
  (value) => value.trim().length > 0,
  (value) => Brand.error(`WorldId must be a non-blank string, received ${JSON.stringify(value)}`),
)
```

規約:

- **型と値コンストラクタを同名で export する**（`type WorldId` と `const WorldId`）。呼び出し側は
  `WorldId('...')` で構築し、型注釈にも同じ識別子を使う。
- コンストラクタは `Brand.refined` で作り、**検証条件と失敗時のメッセージを両方持たせる**。
  `Brand.nominal`（無条件）で済ませず、「非空文字列である」のような最小限の不変条件は型の側に埋め込む。
- **意味的に区別すべき値は、たとえ同じ実体型でも別のブランドにする。** `mc-kernel/domain/quantities.ts` の
  `DeltaTimeSecs` / `MonotonicTimeSecs` / `EpochMillis` は全部 `number` だが、`docs/public-api.md` が
  記録するとおり「特に `MonotonicTimeSecs` と `EpochMillis` の混同は『セーブのタイムスタンプがプロセス起動
  からの経過秒になる』類の事故を生む」。数値としての互換性ではなく、意味の互換性で型を分けること。
- ブランドを跨いだ変換関数は、変換の意味が自明な名前にする（`mc-kernel/domain/coordinates.ts` の
  `blockPositionOfPosition` / `chunkCoordOfBlock` のように `<結果>Of<入力>` の形）。

### 2-2. 閉じたリテラル union とブランドの使い分け

「取り違え防止」だけならブランドで足りるが、**綴り間違いも機械的に弾きたい語彙**（ブロック名・アイテム名など）
はブランデッド文字列ではなく閉じたリテラル union にする。`mc-kernel/domain/block-type.ts` /
`domain/item-type.ts` の規約:

```typescript
const BLOCK_TYPES = ['air', 'stone', /* ... */] as const
type BlockType = (typeof BLOCK_TYPES)[number]
const isBlockType = (value: string): value is BlockType
```

`docs/public-api.md` はこの選択の理由を明示している。

> **なぜリテラル union か（ブランデッド文字列ではなく）**: 挙動は名前比較ではなく能力から読む、というのが
> 設計の主張であり、それを機械検査可能にしているのは閉じたリテラル集合である。ブランドは外部からの侵入は
> 塞ぐが綴り間違いは塞がない（`ItemId('stik')` は通る）。

規約:

- 語彙が閉じている（有限個で、コンパイル時に列挙できる）なら union、開いている（利用側が値を作る）なら
  ブランド、という基準で選ぶこと。
- 2 つの閉じた語彙が交差する場合（`PlaceableItemType = ItemType & BlockType` のような橋渡し型）は、
  交差を**手書きリストとして持たず、両方の roster から計算で導出する**。第 3 の名簿を作らない。
- 網羅性の検査には roster 配列（`BLOCK_TYPES` / `ITEM_TYPES` のような `ReadonlyArray`）を回すこと。
  `switch` に `default` を書いて握り潰さない。

### 2-3. 能力・プロパティの解決関数パターン（加算安全性）

「フラグや設定が将来増えても、既存の消費コードが壊れない」構造が必要な場面では、
`mc-kernel/domain/block-capabilities.ts` の形を踏襲する。

```typescript
const BLOCK_CAPABILITY_DEFAULTS = { passable: false, /* ... */ } as const
type BlockCapabilityFlag = keyof typeof BLOCK_CAPABILITY_DEFAULTS   // 表から導出
type BlockCapabilityOverrides = { readonly [K in BlockCapabilityFlag]?: boolean }
const resolveBlockCapabilities(overrides): BlockCapabilities
```

消費側は完全なレコードを手書きせず、**差分（overrides）だけを書いて解決関数に渡す**。この形にすることで、
新しいフラグやプロパティが増えても消費側のコードはそのまま動く。`docs/versioning.md` §5-2 が明言するとおり、
これによって「フラグが増える」は破壊的変更ではなく加算的変更になる。

新しい公開 struct/enum を設計するときの判断基準:

- 値の集合が増える見込みがあるなら、消費側が完全なリテラルを埋める形にしない。overrides + resolve 関数の形にする。
- 既定値表（`BLOCK_CAPABILITY_DEFAULTS` のような）から型を `keyof` で導出し、**既定値を持たない新フィールドが
  型検査を通らない**ようにする。
- boolean で済むか型付き値が要るかは最初に決め切る。`docs/versioning.md` §5-4 が記録するとおり、
  「boolean から数値・enum へ広げる」のは加算的ではなく破壊的変更である。

### 2-4. Effect `Context.Tag` による Port

サービス境界（時計、プレイヤー状態、チャンクストアなど）は `Context.Tag` で宣言する。
`mc-kernel/domain/clock.ts` が規範形。

```typescript
export type ClockService = {
  readonly monotonicSecs: Effect.Effect<MonotonicTimeSecs>
  readonly wallClockEpochMillis: Effect.Effect<EpochMillis>
}

export class ClockPort extends Context.Tag('@nerima-games/mc-kernel/ClockPort')<ClockPort, ClockService>() {}
```

規約:

- **Tag 識別子文字列はフルパッケージ名を含める**（`'@nerima-games/mc-kernel/ClockPort'`）。他リポジトリと
  衝突しない一意な文字列であることが Effect の Layer 解決の前提であり、この文字列こそが実行時の契約そのもの
  である（§4 で詳述）。
- サービス型（`ClockService`）と Tag クラス（`ClockPort`）を分けて export し、Tag クラスは
  `Context.Tag(...)<Self, Service>()` を継承するだけの薄いクラスにする。
- Port を消費する薄いヘルパ関数（`monotonicSecs` / `wallClockEpochMillis`）も一緒に export し、
  呼び出し側が毎回 `Effect.flatMap(ClockPort, ...)` を書かずに済むようにする。
- **Port の実装（実クロックを読むアダプタ等）は Port を定義したリポジトリに置かない。** kernel は
  `fixedClock` / `FixedClockLayer`（テスト用の決定的実装）だけを持ち、実クロックを読むアダプタは
  利用側リポジトリが注入する。Port と実装を同じ場所に置かないことで、Port を定義するリポジトリが
  プラットフォームに依存しない状態を保つ。
- Port のメソッドが要求する追加のサービスがあるなら、Port 全体にではなく**メソッドのエラー/依存チャネルに
  付ける**。`mc-sim/application/player-service.ts` の `cameraPose: Effect.Effect<CameraPoseSnapshot, never, ClockPort>`
  がその例で、`ClockPort` を要求するのは `cameraPose` だけであり `PlayerServiceApi` の他のメンバは要求しない。
  「一度取得すれば残余要求がないもの」と「呼び出しの都度要求があるもの」を区別すること
  （`mc-kernel/docs/public-api.md` §7 の `FrameServices` 確定の経緯を参照）。

### 2-5. 権威（authority）とミラーの非対称性を型で表す

複数リポジトリが同じ概念に触れる場合、**書き込める側と読むだけの側を型で区別する**。
`CameraPoseSnapshot` はその実例で、`mc-sim` が唯一の発行者、`mc-render` はミラーである。
`mc-sim/application/player-service.ts` のヘッダ:

> mc-render calls `cameraPose` and mirrors the result; there is no path by which a renderer can write a
> pose back, because this API exposes no such method and mc-sim cannot see mc-render at all.

規約: 「A が正、B はミラー」という関係を設計するときは、B 側に書き込み用の公開 API を一切用意しない。
型を読み取り専用にするだけでなく、**そもそも書き込み手段になり得る関数を export しない**ことで非対称性を
保証する。

## 3. 破壊的変更 vs 加算的変更

**このリポジトリ群には自動判定ツールが無い（§4）。** したがって「これは破壊的変更か」の判定は
**人間のレビューでしか行われない**。これは省略ではなく、この標準が要求する主たる審査項目である。
自己レビュー時のチェックリストは [REVIEW_STANDARD.md](./REVIEW_STANDARD.md) の該当項目に従うこと。
ここでは判定に使う具体的な基準を列挙する。

### 3-1. 判定基準

変更が次のいずれかに該当すれば破壊的変更である。

1. **`src/index.ts` の re-export が減る**（モジュールを削除する、`export *` を個別 export に絞る、
   型やメンバを削除する）。
2. **既存の公開関数のシグネチャが呼び出し側から見て狭くなる**（引数が増える／必須になる、返り値の型が
   狭くなる、Effect の依存チャネル `R` が増える）。
3. **`Context.Tag` の識別子文字列を変更する。** 型検査だけでは検出できないが、実行時に Layer 解決が
   壊れる。`docs/versioning.md` §7-1 が実測したとおり、この文字列を変えても TypeScript の型チェックも
   api-extractor のレポートも変化しない ——「見た目上は何も起きていない」が実際には全消費者が壊れる変更で
   あり、レビューでもっとも見落としやすい。
4. **数値・boolean など値の型を広げる**（`docs/versioning.md` §5-4: 「boolean から数値へ広げるのは
   破壊的変更」）。既定値が変わらなくても型が変わればその値を保存・比較しているコードは壊れうる。
5. **必須メンバを追加する。** optional な追加（下記 3-2）と違い、既存の呼び出し側リテラルが
   コンパイルを通らなくなる。

### 3-2. 加算的変更として扱ってよいもの

1. **新しいモジュールやシンボルをバレルに追加する。**
2. **overrides 型（§2-3）に optional なメンバを追加する。** 既定値表に既定値を追加できる場合に限る
   （既定値のないプロパティは型注釈でコンパイルエラーにする設計を維持すること）。
3. **閉じたリテラル union に新しいリテラルを追加する**（`BLOCK_TYPES` / `ITEM_TYPES` を埋める作業）。
   `docs/public-api.md` は「語彙を埋めるのは加算的な作業である。挙動は名前ではなく能力から読むので、
   リテラルが増えても消費側のコードは変わらない」と明記している。
4. **`HarvestContext` のように、引数として渡される struct の全メンバを optional にしたまま新メンバを
   追加する。** `docs/public-api.md` §4-3 の理由: 必須メンバを後から足すと全消費側の呼び出しが壊れるが、
   optional なら 1 つも壊れない。
5. **Effect の依存チャネル `R` を減らす、エラーチャネル `E` を狭める**（呼び出し側からは常に安全な変更）。

### 3-3. 迷う変更は「レビューで議論する」変更である

上記のどちらにも明確に該当しない変更（例: 既存関数の挙動だけが変わり型は変わらない、`interface` の
メンバ順序が変わる、コメントだけが変わる）は、自動ツールでは検出できないという前提のまま
[REVIEW_STANDARD.md](./REVIEW_STANDARD.md) の自己レビューチェックリストに沿ってレビュアーが判断する。
判定に迷う場合は「破壊的変更として扱い、バージョンと変更履歴に明記する」側に倒すこと
（`0.x` の間の bump 規約は各リポジトリの `docs/versioning.md` を参照）。

## 4. 自動 API ロック／スナップショットツールは使わない

**本リポジトリ群には自動生成された公開 API のスナップショット・diff ツールは存在しない。**
「公開 API」とは `src/index.ts` が re-export するものそのものであり、それ以上でもそれ以下でもない
（§1）。破壊的変更の検出は §3 の基準に基づく人間のレビューで行う。

新しくスナップショット/diff ツールを追加する提案（`@microsoft/api-extractor` を含む）は本標準に反する。
これは見落としではなく、検討のうえでの決定である。

**歴史的経緯（参考情報）**: 過去に `api-lock.md` + `scripts/api-lock.ts` という自前の公開 API スナップショット
機構があり、CI で `pnpm api:check` により検査し、「4 週間無変更で API 凍結」という 1.0.0 リリースゲートに
紐づけていた。導入前に `@microsoft/api-extractor` も評価されたが、`Context.Tag`（例:
`ClockPort = Context.Tag('@nerima-games/mc-kernel/ClockPort')`）の宣言が生成する非 export の基底クラス
（`ClockPort_base`）を「forgotten export」として捨ててしまい、Tag 識別子文字列を改変してもレポートが
バイト単位で同一のままになる、という欠陥が実測されていたため不採用となった経緯があった（詳細は
mc-kernel の `docs/versioning.md` に当時の記録が残っていればそちらを参照）。この自前機構自体も、
最終的にはメリットに対して運用コストが見合わないと判断され、組織として撤去されている。今後この種の
仕組みを復活させる提案をする場合は、まずこの経緯と本セクションの決定を踏まえること。
