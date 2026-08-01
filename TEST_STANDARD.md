# テスト標準

適用範囲: nerima-games 配下の全リポジトリ(mc-audio, mc-compose, mc-dev-meta, mc-kernel, mc-meshing,
mc-noise, mc-physics, mc-playground-kit, mc-render, mc-save, mc-sim, mc-worldgen, mx-gameplay,
mx-multiplayer, mx-redstone, mx-ui の 16 リポジトリ)。テストランナーは全リポジトリで vitest。
mx-ui のみ、実ブラウザでの DOM/E2E 検証のために Playwright を追加で使う(`test-browser/` +
`playwright.config.ts`)。

本書はテストの書き方・置き場所・カバレッジゲートを定める。ベンチマーク測定(vitest bench)は
本書の対象外であり、`PERFORMANCE_STANDARD.md` を参照すること。

---

## 1. `pnpm verify` の構成

```console
$ pnpm verify        # typecheck && lint && test
```

`verify` は次の 3 ゲートのみで構成する。

| ゲート | 何を捕まえるか |
| --- | --- |
| `pnpm typecheck` | 型検査。build/test/preview など複数の tsconfig プロジェクトに分かれているリポジトリでは、そのすべてを検査する |
| `pnpm lint` | 静的解析(oxlint 等) |
| `pnpm test` | vitest によるユニットテストの実行(`vitest run`) |

`check:deps`(依存ホワイトリスト/循環検査)と `api:check`(公開 API 差分検査)は、今回のセッション
での変更により仕組み自体が撤去された。過去のドキュメントやコミットログに `pnpm verify` が
`typecheck && lint && check:deps && api:check && test` という 5 段構成だった記述が残っている場合、
それは旧構成である。新規に `verify` を書く・レビューする際は 3 段構成を正としてよい。
`check:deps` 相当のチェックが必要な場合は、`verify` に戻すのではなく個別の CI ステップとして
別立てにすること(§3 参照)。

カバレッジ計測(`pnpm test:coverage` = `vitest run --coverage`)は `verify` に**含めない**。
理由は Playwright の実ブラウザテストと同じ構造で、`verify` は「変更を保存するたびに実行しても
苦にならない」速さを保つゲートであり、カバレッジ集計はレポート生成のオーバーヘッドがあるため
別ステップとして CI に置く(§3)。

---

## 2. テストの置き場所とテスト種別

### 2.1 ユニットテスト(`test/`)

- 各リポジトリのユニットテストは `test/` 直下にフラットに置く。ディレクトリを深く切らない。
- 原則として **ソースモジュール 1 つにつきテストファイル 1 つ**。例えば `domain/rules.ts` に
  対して `test/rules.test.ts`。
- 複数のテストファイルから共有して使うダブル(スタブ/フェイク実装など)やフィクスチャは
  `test/support/`(または `test/fixtures/`)にまとめる。実例は mx-gameplay:

  ```
  mx-gameplay/test/support/player-service-double.ts
  mx-gameplay/test/support/inventory-service-double.ts
  mx-gameplay/test/support/chunk-store-double.ts
  mx-gameplay/test/support/entity-manager-double.ts
  mx-gameplay/test/support/frame-runner.ts
  mx-gameplay/test/support/frame-services.ts
  ```

  これらは特定の 1 テストのための道具ではなく、`in-memory-player.test.ts` や
  `in-memory-inventory.test.ts` など複数のテストファイルが共有して使うダブルなので、
  `test/` 直下ではなく `test/support/` に切り出してある。逆に言えば、1 ファイルからしか
  使わないヘルパーをここに置く理由はない。

### 2.2 ブラウザ/E2E テスト(Playwright)

- ブラウザ/E2E テストは、**実 DOM でしか答えられない問いにだけ**書く。具体的には
  「実 `Document` への mount」「実測ピクセル(スクリーンショット比較)」「実レイアウト/幾何」の
  3 種類。それ以外(属性の有無、状態遷移、純関数としての射影など)は vitest の `test/` 側の方が
  速く厳密に答えられるため、そちらに書く。
- 現状この構成が必要なのは mx-ui のみで、`test-browser/` + `playwright.config.ts` を持つ。
  `test-browser/*.spec.ts` が Playwright 側、`test/*.test.ts` が vitest 側であり、
  両者は互いの代替ではなく担当する問いの種類が違う。
- Playwright は `pnpm test:browser` で単独実行し、`pnpm verify` にも CI の必須ゲートにも
  含めない(CI 実行環境にブラウザバイナリが無いため)。「`playwright install` をしていない」という
  ただの環境不備が、コードについて何も語らない赤ビルドになるのを避けるための切り分けである。
  リポジトリにブラウザ操作が必要になった場合のみ、この構成を追加すること。

---

## 3. カバレッジゲート: 4 指標 99%、即日・全リポジトリ必須、段階移行なし

**組織としての決定事項**: vitest `--coverage`(provider: v8)による
**statements / branches / functions / lines の 4 指標すべてで 99%** のしきい値を、
**全 16 リポジトリの CI に、ロールアウト当日から即時・一律に適用する**。

これは猶予期間や段階的ロールアウトを伴わない。あるリポジトリのカバレッジが低いことは、
ロールアウト日にそのリポジトリの CI が赤くなる理由であって、しきい値を緩める理由ではない。
「まず一部リポジトリから」「まず 90% から始めて段階的に上げる」といった移行計画は採用しない。
既知の未達は §4 に列挙し、追跡対象の作業として扱う。

### 3.1 CI での組み込み方

CI は次の 2 ステップを両方とも必須ゲートとして実行する。

```console
$ pnpm verify          # typecheck && lint && test — §1
$ pnpm test:coverage   # vitest run --coverage — 4 指標 99% のしきい値判定はここ
```

`vitest.config.ts` の `test.coverage.thresholds` を下回った場合、`vitest run --coverage`自体が
非ゼロで終了するため、しきい値判定のために追加のスクリプトを書く必要はない。

### 3.2 設定の実例(mc-kernel)

`mc-kernel/vitest.config.ts` は現時点で 99% ゲートが有効な実例であり、他リポジトリが
これから設定する際の具体形として使ってよい。

```ts
coverage: {
  provider: 'v8',
  enabled: false,
  include: ['index.ts', 'domain/**/*.ts'],
  exclude: [
    '**/*.d.ts',
    '**/*.config.ts',
    '**/*.test.ts',
    '**/*.spec.ts',
    // PURE_TYPE: 宣言のみで実行可能な文が 0 のファイル。v8 はこの種のファイルを
    // 100% ではなく 0% として報告するため、含めると見出しの数字が意味を失う。
    // このファイルの契約は test/clock-and-frame.test.ts で検証され、
    // `pnpm typecheck` で強制される。
    'domain/frame.ts',
  ],
  all: true,
  reporter: ['text', 'json', 'html', 'lcov'],
  reportsDirectory: './coverage',
  thresholds: { branches: 99, functions: 99, lines: 99, statements: 99 },
},
```

この形から読み取るべき点:

- `provider: 'v8'` を全リポジトリで統一する。
- `enabled: false` はこのブロック自体のデフォルト無効化であり、実行時は `--coverage` フラグで
  上書きする(`pnpm test:coverage` = `vitest run --coverage`)。
- `exclude` に型のみのファイル(実行可能な文を持たないファイル)を個別に列挙し、**除外理由を
  コメントで書く**。v8 は実行可能な文が 0 のファイルを 0% と報告してしまうため、除外しないと
  見出しの数字がその分だけ無意味に下がる。「型だから」という理由だけで機械的に全 `*.d.ts` 相当を
  除外するのではなく、除外の妥当性が型検査(`pnpm typecheck`)や既存テストによって
  別途保証されていることを明記すること。
- しきい値は 100% ではなく **99%**。ゲートの目的は「回帰の検知」であり、現在の実測値ぴったりに
  ピン留めすると、無関係なリファクタ 1 つで簡単に赤くなり、「テストを書く」ではなく
  「数字を上げる/しきい値を下げる」対応を誘発する。1% の余白は、到達が難しい分岐 1〜2 本分の
  遊びであり、無条件の緩和ではない。
- カバレッジを数字のためだけに埋めない。mc-kernel での実績では、未到達だった分岐の大半は
  「型が排除している入力へのフォールバック」(`?? 0` を閉じた union の上に書く、等)であり、
  正しい対処はテストの追加ではなく **到達不能な分岐そのものを消す**(ロジックを total にする)
  ことだった。カバレッジ未達に対処する際は、まず「このテストは本当に必要な仕様を守っているか」
  「この分岐は本当に到達可能か」を先に問うこと。

---

## 4. 既知の非適合(ロールアウト時点)

以下は本ゲートのロールアウト日時点で 99% を満たさない、または達成状況が未計測のリポジトリ。
**これらはゲートを弱める理由ではなく、追跡対象の未完了作業として扱う**(nerima-lisp の
`CONFORMANCE.md` が既知の例外を隠さずに理由付きで列挙するのと同じ扱い方)。ロールアウト日に
これらのリポジトリの CI が赤くなることは想定内であり、標準の欠陥ではない。

| リポジトリ | 実測(コミット時点) | ロールアウト日の状態 | 扱い |
| --- | --- | --- | --- |
| mc-audio | statements 95.52%(577/604)/ branches 95.52%(192/201)/ **functions 84.12%(53/63)** / lines 95.52% | 4 指標とも 99% 未達 → CI 赤 | カバレッジ差分の解消をタスク化して追跡する。しきい値の一時緩和は行わない |
| mc-compose | リポジトリ直下に `coverage/coverage-final.json` が存在せず(ワークツリー内にのみ古いものがあり、本体では未計測)、現状値が不明 | ベースライン未取得 → ロールアウト前に `pnpm test:coverage` を一度走らせ、現在地を明らかにすることが前提作業 | ベースライン取得を最優先タスクとして扱う。「測っていないので後回し」にはしない |
| mc-playground-kit | statements 98.51%(197/200 相当)/ branches 100% / **functions 96.29%** / lines 98.51% | functions のみ 99% 未達 → CI 赤 | 4 指標中 1 つが僅差で未達。他 3 指標が高水準であることはしきい値緩和の根拠にならない |

mc-kernel、mx-ui、mx-gameplay、mx-redstone は本ゲートが既に有効かつ通過している。
上記 3 リポジトリ以外で `vitest.config.ts` の `thresholds` がコメントアウトされたままのリポジトリは、
本ゲートのロールアウトに合わせて有効化すること(§3.2 の形をそのまま流用してよい)。

数値は測定時点のものであり、ロールアウト実施前に各リポジトリで
`pnpm test:coverage`(または `coverage/coverage-final.json`)を再確認し、変動があれば
この表を更新すること。

---

## 5. ベンチマークテストについて

パフォーマンス測定(vitest bench によるベンチマーク)は本書の対象外。`PERFORMANCE_STANDARD.md`
を参照すること。カバレッジゲートとベンチマークは別の関心事であり、混同しないこと
(カバレッジ 99% はコードパスが実行されたかどうかの指標であり、速度や割り当てを保証しない)。
