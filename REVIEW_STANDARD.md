# nerima-games レビュー標準

nerima-games org の全16リポジトリ(`mc-audio` `mc-compose` `mc-dev-meta` `mc-kernel`
`mc-meshing` `mc-noise` `mc-physics` `mc-playground-kit` `mc-render` `mc-save` `mc-sim`
`mc-worldgen` `mx-gameplay` `mx-multiplayer` `mx-redstone` `mx-ui`)が従う PR レビュー基準です。
対象読者は人間のメンテナ (take) 1名と、Claude Code などの AI コーディングエージェントです。
複数人の人間レビュアーが分業する体制は前提にしていません。**この org にレビュアーは実質1人(+
エージェント)しかいない**、という事実がこの文書のあらゆる設計判断の起点です。

## 1. レビューモデル: ピアレビューではなくセルフレビュー

nerima-games のブランチルールセットは、`pull_request` ルール(承認必須)を一切要求しません。
これは見落としではなく、`private-terraform` 側の設計判断です。
`projects/github/rulesets.tf` の `locals.standard_branch_rules` 直前のコメントが理由を明記しています。

> None of these rulesets include a pull_request rule requiring an approving
> review. It used to, on cl-weave: in a one-maintainer org nothing can ever
> merge under that requirement, because GitHub does not accept a
> self-approval and a ruleset is not bypassed by `gh pr merge --admin` the way
> classic branch protection was. The org's own REVIEW_STANDARD.md decides the
> opposite -- self-merge is allowed, because the overwhelming majority of
> commits have a single author and requiring another reviewer would break the
> rule on its first pull request. The conditions it asks for instead (read the
> whole diff, fill in the review checklist, wait for CI) are not expressible
> as a ruleset.

要点は次の3つです。

1. **GitHub は self-approval を承認としてカウントしない。** 1人しかいない org で
   `required_approving_review_count >= 1` を設定すると、そのリポジトリの最初の PR から
   誰も merge できなくなる。これは理論上の懸念ではなく、`cl-weave` で実際に踏んだ制約です。
2. **`gh pr merge --admin` のような bypass は、ruleset には存在しない。** classic branch
   protection と違い、ruleset は「管理者権限で無理やり通す」抜け道を前提に設計されていない。
   したがって「承認必須にしておいて、いざとなったら admin で突破する」運用は成立しません。
3. だから nerima-games のルールセットは `required_signatures` と `non_fast_forward` だけを
   GitHub 側の機械的ゲートとして残し、**「差分を全部読む」「レビューチェックリストを埋める」
   「CI を待つ」という本来レビューが担うべき条件は、GitHub の設定ではなく、この
   `REVIEW_STANDARD.md` という人間/エージェント向けのプロセス文書として存在します。**

つまり、この文書が定める内容は GitHub 上のどの ruleset にも自動化されていません。
著者(人間かエージェントか問わず)が merge 前に自分で読み、自分で守る前提の文書です。
`darwin-vz-nix` のように `pull_request` ゲートを持つ例外リポジトリでも
`required_approving_review_count = 0` であり、「PR は必須だが承認者は不要」という
同じ one-maintainer の理屈の上に立っています。承認者がいないことは怠慢ではなく、
このレビューモデルの前提です。

## 2. セルフレビューチェックリスト

PR を merge する前に、著者自身が以下を上から順に確認します。飛ばした項目があるなら、
merge before ではなく PR の説明欄にその理由を書いてください。

- [ ] **差分を全部読んだか。** `git diff` の1行目から最後の行まで実際に読んだか。
  変更されたファイル名の一覧を眺めて「知っているファイルだから大丈夫」で済ませていないか。
  特に生成AIが書いた差分は、意図しない広範囲の書き換え(フォーマッタの意図しない適用、
  未使用 import の残存、コメントの消失)が混ざりやすいので、diff の行数が多いほど
  この確認を省略したくなるが、それこそが省略してはいけない理由です。
- [ ] **`pnpm verify` が通ったか。** `PACKAGE_STANDARD.md` が定める移行後の
  `scripts.verify` は `pnpm typecheck && pnpm lint && pnpm test` の3段です。
  `check:deps`(`scripts/check-dependency-whitelist.ts`)と `api:check`
  (`scripts/api-lock.ts`)は今回のセッションで org 標準から削除されたため、
  現時点の `verify` はこの3段のみで、それ以上を待つ必要はありません
  (削除の経緯は `PACKAGE_STANDARD.md` の「`api-lock.md` / `scripts/api-lock.ts` の廃止」
  節および「`scripts/check-dependency-whitelist.ts` の廃止」節を参照)。
- [ ] **挙動が変わったなら、対応する `docs/*.md` を更新したか。** 各リポジトリの
  `docs/README.md` `docs/architecture.md` `docs/responsibility.md` `docs/public-api.md`
  `docs/testing.md` `docs/versioning.md` `docs/design-notes.md`(条件付きで `docs/porting.md`)
  のうち、どのページが対象になるかは `DOCS_STANDARD.md`(本 org リポジトリに別途定義)の
  必須ページ定義に従って判断してください。コードだけ変えて該当ページを放置した PR は
  未完了として扱います。
- [ ] **新しく `@nerima-games/*` の import を追加したなら、`DEPENDENCY_POLICY.md` を
  確認したか。** `PACKAGE_STANDARD.md` の4層依存アーキテクチャ(Tier1〜Tier4 + 層外の
  `mc-dev-meta`)は「同じ層か下の層へのみ依存する」という向きの制約を課しています。
  新しい org 内 import が Tier を逆流していないか、Tier3 の4リポジトリ間で横の依存を
  作っていないかは、`no-restricted-imports`(`oxlint.json`)で機械的に弾かれる場合と
  弾かれない場合があるため、追加のたびに `DEPENDENCY_POLICY.md` 側の判断基準と
  突き合わせてください。
- [ ] **PR の粒度は1つの論理的関心事に閉じているか。** 「ついでに」直した無関係な
  リファクタや、複数リポジトリにまたがる変更を1つの PR に混ぜていないか。
  レビュアーが1人(+エージェント)しかいない体制では、大きな PR は次の日に読み返しても
  自分自身が文脈を再構築するコストを払うことになります。小さく単機能な PR を優先し、
  「あとで分けるくらいなら最初から分ける」を既定にしてください。

## 3. AI コーディングエージェントが著者の場合

人間が著者の PR と、エージェントが著者の PR に別のルールは設けません。ただし
エージェントには次の2点を明示的に要求します。

1. **実際にコマンドを実行して確認したか。** `pnpm verify` やテストコマンドについて、
   「この変更なら通るはず」という推論だけで mergeable と判断してはいけません。
   自分のセッション内で実際にコマンドを実行し、その出力を確認した場合に限って
   「通った」と申告してください。サンドボックスや権限の制約で実行できなかった場合は、
   実行できなかったこと自体を隠さず申告してください(次項)。
2. **PR の説明欄に、検証済みの範囲と未検証の範囲を明示したか。** 「動作確認済み」と
   一括りにせず、「`pnpm verify` は実行して成功を確認した」「ブラウザでの目視確認
   (`apps/preview-*` や `mx-ui` の `test:browser`)は環境上実行していない」のように、
   何を確認し何を確認していないかを分けて書いてください。未検証の項目を隠したまま
   self-merge することは、このレビューモデル全体(セクション1)の前提を壊します。
   ピアレビューがない代わりに著者の自己申告の正直さがゲートの役割を担っているため、
   ここでの省略や誇張はセクション1の一次資料がGitHub側で保証できない部分を
   まるごと無効化します。

## 4. CI 待ちは self-merge の絶対条件

承認者がいなくても、CI は誰の主観にも依存しない客観的なゲートとして機能します。
「自分で読んだから大丈夫」で CI の完了を待たずに merge することは、このレビューモデルの
唯一の客観的チェックを放棄する行為であり、認めません。**self-merge であることは
CI を待たなくてよい理由には一切なりません。**

CI が要求するカバレッジ基準(99%のブランチ/関数/行/文カバレッジ)の詳細は
`TEST_STANDARD.md`(本 org リポジトリに別途定義)を参照してください。本書では重複させず、
「CI がそのゲートを red にしている限り merge を待つ」という運用側の要求だけを定めます。

ただし、org 内には **99%ゲートの導入直後から確実に red になることが分かっているリポジトリが
3つ**あります。`mc-audio` `mc-compose` `mc-playground-kit` です(いずれも
`vitest.config.ts` の `thresholds` が現時点でコメントアウトされたままで、有効化した瞬間に
現状のカバレッジ不足が表面化します)。この3リポジトリに限り、次を明示的な例外運用とします。

- **known-red の required check を抱えたまま self-merge する場合、PR の説明欄に
  「なぜこの PR を、この既知の red のまま merge してよいと判断したか」を明記すること。**
  例:「このリポジトリは 99% ゲート導入時点でカバレッジ不足が既知(TEST_STANDARD.md
  ロールアウト計画を参照)。本 PR はその不足を悪化させていないことを `test:coverage` の
  before/after 比較で確認済み」のように、silent に merge しないための一文を必ず残す。
- 逆に言えば、この3リポジトリ以外で required check が red のまま merge することは
  正当化を用意しても認めません。この3リポジトリの例外は「ロールアウト直後の既知の負債」に
  対する期限付き措置であり、恒常的な抜け道ではありません。

## 5. Issue ラベル体系

チームではなく1人+エージェントの運用であることを踏まえ、意図的に小さく保ちます。
`triage/priority: high` のような多段のラベル階層は、ラベルを整理するためのラベル作業自体が
オーバーヘッドになるため作りません。

| ラベル | 用途 |
|---|---|
| `bug` | 既存の挙動が仕様/期待に反している |
| `enhancement` | 新機能・新しい挙動の追加提案 |
| `tech-debt` | 挙動は変えないが、構造・依存・テストの整理が必要 (例: `PACKAGE_STANDARD.md` の `src/` 移行のような org 標準への追従) |
| `blocked` | 他の Issue/PR、あるいは外部要因(依存ライブラリの更新待ちなど)に依存していて今は着手できない |

GitHub 標準で最初から付与される `duplicate` `invalid` `wontfix` `question` などは
そのまま残して構いません。上記4つに加えて新しいラベルを増やす前に、「そのラベルで
検索・分類する場面が実際に発生しているか」を自問してください。発生していないなら
増やさないのが既定です。
