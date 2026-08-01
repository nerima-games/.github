# nerima-games パフォーマンス標準

nerima-games org の全16リポジトリ (`mc-audio` `mc-compose` `mc-dev-meta` `mc-kernel`
`mc-meshing` `mc-noise` `mc-physics` `mc-playground-kit` `mc-render` `mc-save` `mc-sim`
`mc-worldgen` `mx-gameplay` `mx-multiplayer` `mx-redstone` `mx-ui`) に対して、
ベンチマーク(性能計測)をどのツールで・どこに・いつ書き・どう実行し・CIでどう扱うかを定める文書です。

## 0. この文書の位置づけ — 新規導入であり、既存慣行の追認ではない

**org 全体でベンチマーク用のツールが標準化されたことは、この文書の執筆時点で一度もありません。**
今回のセッションで `mc-audio` `mc-compose` `mc-playground-kit` `mc-kernel` `mx-ui` の5リポジトリを
個別に確認し、`tinybench` への依存、`vitest.config.ts` の `benchmark` 設定、`bench/` や
`benchmarks/` ディレクトリのいずれも見つかりませんでした。この5リポジトリに関する限り、
本書はゼロから書き起こす新規標準です。

**ただし例外が3つあります。** `mc-meshing` `mc-noise` `mc-worldgen` の3リポジトリには、
`vitest bench` とは別系統の、自作のベンチマーク基盤が**既に存在します**。

- `scripts/bench-harness.ts`(3リポジトリで共通の設計) — `tsx` + `node:perf_hooks` で書かれた
  手製の計測フレームワークです。`pnpm bench` から `scripts/bench-meshing.ts`
  (`mc-meshing`)、`scripts/bench-noise.ts`(`mc-noise`)、`scripts/bench-terrain.ts`
  (`mc-worldgen`)を実行します。
- 計測結果は `scripts/bench-baseline.json` としてコミットされ、実行のたびに前回のベースラインと
  比較します。比較は絶対値(何ミリ秒)ではなく、同一プロセス内で2つの実装を測って比を取る
  **guard**(例: `mc-meshing/scripts/bench-meshing.ts` の
  `set-membership/hashset-vs-lookup-table`)と、計測対象を同一プロセスの基準ワークロードで
  正規化する **workload** の2種類の比率で行われ、閾値を外れると `pnpm bench` が非ゼロで終了します。
- `mc-meshing/docs/testing.md` §7、`mc-noise/domain/octaves.ts` の冒頭コメント
  (「plan.md §5.2 の性能例外はまず計測してから実装する」)が、この基盤が作られた理由を
  詳しく書いています。要旨は、greedy meshing や octave ループのような
  「速さそのものが存在理由」のコードを、Effect 慣用スタイルへの「修正」から守るために、
  実装より先に計測手段を用意した、というものです。
- `pnpm verify` には**含まれません**。3リポジトリとも `docs/testing.md` に
  「CI は公開リポジトリの全PRで走る共有リソースであり、wall-clock 計測を乗せる場所ではない」
  という同じ理由が書かれています。

この3リポジトリの資産は本書が定義するより前から存在し、本書より高度な回帰検出
(guard/workload比率・コミット済みベースライン・許容度パラメータ)を備えています。
**本書はこの3リポジトリの既存資産を置き換えることを要求しません。** 本書が定めるのは、
「今後、org のどこかで新しくベンチマークを書くときに何を使うか」という標準であり、
既存の `scripts/bench-*.ts` + `bench-harness.ts` は現状維持で構いません
(将来的な統合を検討する余地はありますが、それは本書のスコープ外の、別途の判断です)。

## 1. 採用ツール — `vitest bench`

新しくベンチマークを書く場合、org 標準は vitest 組み込みのベンチマーク機能
(`vitest bench` コマンド、`.bench.ts` ファイル、または `defineConfig({ test: { benchmark: {...} } })`)
とします。

**理由は単純です。全16リポジトリが既にテストランナーとして vitest を採用しています。**
`vitest bench` を使う限り、`package.json` の `devDependencies` に新しい行は増えません。
vitest のベンチマーク機能は内部で `tinybench` を利用していますが、それは vitest 自体の依存として
既に解決されており、各リポジトリが `tinybench` を自分の `devDependencies` に個別に持つ必要は
ありません。

`tinybench` を各リポジトリに直接追加する案は検討した上で見送りました。理由は上と同じで、
`vitest bench` を使えば同じ計測エンジンを追加の依存なしに得られるため、直接依存として
持つ理由がないためです。

3リポジトリの既存の自作ハーネス(`scripts/bench-harness.ts`)は `vitest bench` の代替ではなく、
別の設計判断です。`vitest bench` には baseline のコミットや guard/workload 比率のような
回帰ゲート機能が組み込まれていないため、既存3リポジトリが独自に用意したこれらの機能を
`vitest bench` へ移行しても得るものがありません。両者は当面併存します。

## 2. ベンチマークファイルの置き場所

`PACKAGE_STANDARD.md` が定める `src/` 再構成後を前提に、ベンチマークは
**計測対象のコードと同じディレクトリに `*.bench.ts` としてコロケートします。**
これは vitest 自身の慣例(`*.test.ts` をテスト対象と同じ階層、または `test/` に置く発想の延長で、
`*.bench.ts` を `*.test.ts` と対にする置き方)に従うものです。

```
<repo>/src/domain/
├── mesh.ts
├── mesh.bench.ts      # 新規に書く場合はここ
├── octaves.ts
└── octaves.bench.ts   # 新規に書く場合はここ
```

具体的な候補としてどこが該当しうるかを、実際にドメイン層を読んだ上で示します。

- **`mc-meshing/domain/mesh.ts`** — greedy meshing(隣接する同種の面をマージして矩形にまとめる処理)
  本体です。ファイル冒頭のコメントが「greedy merge の唯一の存在理由は速さである」と明言しており、
  `src/` 移行後であれば `src/domain/mesh.bench.ts` がこの処理の新規ベンチマークの自然な置き場所に
  なります(既存の `scripts/bench-meshing.ts` は上記の通りそのまま残ります)。
- **`mc-noise/domain/octaves.ts`** — オクターブ合成(fBm)のループです。冒頭コメントに
  「`let` + `for` で書かれた4スカラーのループが world generation の最もホットなパスである」と
  明記され、`Array.from().reduce` や `Effect.reduce` への書き換えが最大6.6倍遅いことまで
  計測済みです。`src/domain/octaves.bench.ts` が該当します。
- **`mc-noise/domain/perlin.ts`** — Perlin 勾配ノイズの 2D/3D カーネルです。ノイズ合成の
  最内周に位置し、`octaves.ts` のループから毎サンプル呼ばれる関数であるため、
  同様に `src/domain/perlin.bench.ts` が候補になります。

いずれも「ドメイン層の純粋関数を計測する」という点で一貫しており、`src/application/` や
`src/stages/` のようなステートフルな層にベンチマークを書く必要は通常ありません
(性能が問題になるのは、これらの下にある純粋なホットループであることが大半です)。

## 3. ベンチマークを書くきっかけ — 全ての変更にではなく、性能が争点になる変更にだけ

ベンチマークを書くことを機械的に義務化しません。義務化すると「単純な CRUD 的変更にまで
性能証明を要求する」過剰適用になり、`mc-noise/domain/octaves.ts` のコメントが批判する
「実測なしの性能主張」を、今度は逆方向に(不要な計測の氾濫として)繰り返すだけです。

書くべきタイミングの目安:

- **ホットパスのアルゴリズムを変える、または置き換える提案がある場合。** 典型例が greedy
  meshing で、`mc-meshing/domain/mesh.ts` は「マージ後のほうが速い」という主張を
  `scripts/bench-meshing.ts` なしには誰も検証できなかった、という経緯を持ちます。
  同種の提案(例: 別のデータ構造への切り替え、別のアルゴリズムへの置換)は書く前に測ります。
- **`domain/` 内に既に「PERFORMANCE EXCEPTION」「性能例外」と明記された箇所を触る場合。**
  `mc-noise/domain/octaves.ts` の `let` + `for` ループや、`mc-meshing/domain/mesh.ts` の
  ネイティブ `Set` 利用がこれに当たります。これらは "Effect 慣用スタイルへの「修正」を
  実測で止める" ためのコメントが既についており、触るなら計測を伴わせます。
- **「速くなった/遅くなった」という主張を PR の説明や docs に書く場合。** 主張には対応する
  ベンチマークの数字を伴わせます。数字のない性能主張は書きません。

逆に書かなくてよい典型:

- Tier3 (`mx-gameplay` `mx-redstone` `mx-ui` `mx-multiplayer`) のような、他モジュールを
  オーケストレーションする層の通常の機能追加。ホットパスは基本的に Tier1(`mc-kernel`
  `mc-noise` `mc-meshing` `mc-physics` `mc-save` `mc-audio`)側のライブラリに閉じています。
- バグ修正、型の整理、リファクタリングで、計算量やアロケーションのパターンが変わらないもの。

## 4. 実行方法 — `pnpm bench`

新規にベンチマークを導入するリポジトリでは、`package.json` の `scripts` に以下を追加します。

```json
"scripts": {
  "bench": "vitest bench"
}
```

`mc-meshing` `mc-noise` `mc-worldgen` の3リポジトリは、`pnpm bench` が既に
`tsx scripts/bench-*.ts` に割り当てられています。本書はこの3リポジトリで
`pnpm bench` を上書きすることを求めません。この3リポジトリで `vitest bench` による
ベンチマークも併せて書きたい場合は、`bench:vitest` のような別名のスクリプトを使うか、
既存の `scripts/bench-harness.ts` 体系へ寄せて書くかを個別に判断してください
(どちらを選ぶかは本書のスコープ外です)。

## 5. CI でのゲーティング — 当面はハードゲートにしない

**`vitest bench` の結果を CI の合否判定には使いません。** 実行して結果を記録するだけにとどめ、
数値が悪化しても CI を失敗させません。

理由は次の2つです。

1. **まだベースラインがない。** 導入直後の1回の実行結果を「正常値」として固定し、
   以降それより遅ければ即失敗、というゲートは、初回の実行環境のノイズをそのまま
   基準に埋め込むことになります。数サイクル(目安として、org 標準としてこの文書が
   最初にマージされてから数週間〜数ヶ月、複数回のベンチマーク実行)分の結果が
   蓄積し、ばらつきの幅が見えてから、ハードゲート化を再検討します。
2. **先例が既にある。** `mc-meshing` `mc-noise` `mc-worldgen` の既存ベンチマーク基盤は
   ベースラインを持つにもかかわらず、あえて `pnpm verify` (CI ゲート) には含めていません。
   `docs/testing.md` が明記する理由は「CI は公開リポジトリの全PRで走る共有リソースであり、
   wall-clock 計測はそこに乗せるものではない」というものです。本書はこの判断を
   踏襲します。よりゲート機構が単純な `vitest bench` を、より複雑な機構を持つ既存基盤より
   先に CI ゲート化する理由はありません。

当面の運用は「実行して、出力を見る」だけです。CI 上で実行する場合も、ログまたは
アーティファクトとして結果を残すにとどめ、閾値判定・exit code によるビルド失敗は
実装しません。ベースラインの蓄積とばらつきの実測を経てから、org として
ハードゲート化するかどうか・する場合の許容度をどう置くかを改めて定めます。

## 6. この文書の適用範囲

本書が定めるのは、ベンチマークに使うツール(`vitest bench`)、新規ベンチマークファイルの
置き場所(`src/` 配下への `*.bench.ts` コロケート)、書くきっかけの目安、実行スクリプト
(`pnpm bench`)、CI でのゲーティング方針(当面ハードゲートにしない)です。

`mc-meshing` `mc-noise` `mc-worldgen` の既存の自作ベンチマーク基盤(`scripts/bench-harness.ts`
とその上に立つ `scripts/bench-*.ts`、`scripts/bench-baseline.json`)の仕様や運用は本書の
対象外です。それらの詳細は各リポジトリの `docs/testing.md` を参照してください。
`src/` 再構成そのもの(ディレクトリツリー、`package.json` の必須フィールド)は
`PACKAGE_STANDARD.md` を参照してください。
