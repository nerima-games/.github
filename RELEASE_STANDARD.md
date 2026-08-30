# リリース標準

nerima-games organization 配下の TypeScript / Effect-ts パッケージ群における、バージョニング・CHANGELOG 生成・公開(publish)・0.x → 1.0.0 昇格の統一ルールを定める。

対象は `mc-dev-meta` を除く 15 リポジトリ(`mc-kernel` / `mc-noise` / `mc-meshing` / `mc-physics` / `mc-save` / `mc-audio` / `mc-worldgen` / `mc-sim` / `mc-render` / `mc-playground-kit` / `mx-gameplay` / `mx-redstone` / `mx-ui` / `mx-multiplayer` / `mc-compose`)。`mc-dev-meta` は `package.json` に `"private": true` が明示され、説明文にも "Never published." と書かれている開発用 pnpm workspace バインダーであり、公開パッケージではないためスコープ外とする。

## 0. 現状(2026-08-30 時点、Wave 0 適用前に再確認した事実)

以下は Wave 0 のロールアウトにあたって同期スナップショット(15/16リポジトリ、`mc-dev-meta`
除く)を再検証した結果であり、今回のスコープの前提となる。この文書が最初に書かれた
2026-08-01 時点からの主な変化は「リリース基盤ゼロ」の状態を `mc-kernel` が単独で抜け出した
ことです。

- **リリース基盤があるのは `mc-kernel` のみ。** `mc-kernel` は既に `.github/workflows/release.yaml`
  (detect → publish → tag の3ジョブ構成、§3 参照)を持ち、`0.5.0` まで実際に公開実績がある。
  他14リポジトリ(`mc-dev-meta` を除く)には `.github/workflows/release.yaml` が存在しない。
  `.changeset/` ディレクトリ、`@changesets/cli` への依存、リポジトリ直下の `CHANGELOG.md` は
  依然としてどのリポジトリにも存在しない(kernel も未導入。kernel の `release.yaml` は
  changesets を使わず、`package.json#version` の diff だけで publish を判定する)。
- **`publishConfig.access` はまだ `restricted` のまま。** 確認できた15リポジトリ全部
  (`mc-kernel` を含む)の `package.json` がいずれも

  ```json
  "publishConfig": {
    "registry": "https://npm.pkg.github.com",
    "access": "restricted"
  }
  ```

  を持つ。2026-08-08 にレジストリ側のパッケージ可視性は `public` へ変更済みだが(§2参照)、
  `package.json` 側の `access` フィールドはどのリポジトリでもまだ追随していない
  — これが本書 §2 の変更点である。
- **バージョンは全リポジトリ 0.x のまま。** 観測範囲は `0.1.3`(`mc-meshing`)〜`0.5.0`
  (`mc-kernel`)。`mc-kernel` が最も進んでいるが、1.0.0 に到達したリポジトリはまだない。
- **可視性は `public`。** `takeokunn/private-terraform/projects/github/repos_nerima_games.tf` で 16 リポジトリすべてが `visibility = "public"` と定義されている。private ではない点に注意する(GitHub Packages への公開設定・認証方針を検討する際の前提が変わる)。

## 1. Changesets 導入

### 1.1 採用パッケージ

全 15 対象リポジトリに [`@changesets/cli`](https://github.com/changesets/changesets) を `devDependency` として導入し、`changeset` コマンド群(`changeset add` / `changeset version` / `changeset publish` 相当の運用、後述の通り publish 自体は CI の GitHub Packages 公開ステップが担う)をバージョニングと CHANGELOG 生成の単一の入り口とする。

各リポジトリで以下を行う:

```bash
pnpm add -D @changesets/cli
pnpm changeset init
```

`pnpm changeset init` が生成する `.changeset/config.json` は、`access` を `public`(GitHub Packages の `publishConfig.access` と一致させる。2026-08-30 に §2 が `restricted` から改訂したのに合わせる)、`baseBranch` を `main` に設定する。`changelog` 生成器は既定の `@changesets/changelog-git` ではなく、リポジトリ URL・PR 番号へのリンクを含む `@changesets/changelog-github` を使うことを推奨する(GitHub 上でリポジトリを跨いだレビューがしやすくなるため)。

### 1.2 PR ごとの changeset 追加

**ユーザー向けの変更(公開 API・振る舞い・依存関係に影響する変更)を含む PR には、必ず 1 つ以上の changeset ファイルを含める。** 手順は次の通り:

1. 変更を行ったブランチ上で `pnpm changeset` を実行する。
2. 変更が影響するパッケージを選択し、bump の種類(`patch` / `minor` / `major`)を選ぶ。
3. 変更内容を要約する短い説明文を書く。これがそのまま `CHANGELOG.md` のエントリになる。
4. 生成された `.changeset/*.md` を PR に含めてコミットする。

CI(`ci.yaml`)に `changeset status --since=main`(または同等のチェック)を追加し、`docs/` のみの変更や CI 設定のみの変更など明らかに not-user-facing な PR を除き、changeset の付け忘れを検出する。ここは各リポジトリの `ci.yaml` 側の変更として別途扱う(本ドキュメントはポリシーの定義に留める)。

### 1.3 バージョン bump と CHANGELOG 生成

- `main` に changeset 付きの PR がマージされると、changesets のリリース PR ワークフロー(`changesets/action` を利用する GitHub Actions ジョブ)が `.changeset/*.md` を集約し、`package.json#version` の bump と `CHANGELOG.md` の追記を行う "Version Packages" PR を自動生成・更新する。
- この "Version Packages" PR 自体はコード変更を含まない(バージョン番号と CHANGELOG のみ)。人間のレビュー(基本的には maintainer である take)を経てマージする。
- 「PR マージ = バージョン確定」であり、任意のタイミングで手動 `npm version` することは禁止する。version の唯一の変更経路は changesets を通すこと。

## 2. 公開先: GitHub Packages(public)の正式化(2026-08-30 改訂)

**この節は当初 `access: "restricted"` を正式方針としていたが、Wave 0 でそれを覆し `"public"` に変更する。** 上書きされる記述は本書自身のこの節(旧稿)であり、理由は次の通り:

- **2026-08-08 に GitHub Packages 側のパッケージ可視性を全パッケージ `public` へ変更済み。** レジストリ側の設定はもう `restricted` ではない。
- `package.json#publishConfig.access` が `"restricted"` のまま新しいバージョンを `pnpm publish` すると、npm クライアントはそのフィールドをレジストリへ送る値として使うため、**新規 publish のたびにパッケージが private(restricted)へ差し戻される**。これは PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」 が明記する事故で、`mc-compose` のような下流の `pnpm install`(GitHub Packages から `@nerima-games/*` を取得する CI ステップ)が 403 で失敗する原因になる。
- リポジトリ自体の GitHub 可視性が `public`(Terraform 定義より)であることと、パッケージが `restricted` であることは独立した設定だったが、この独立性そのものが事故の温床だったため、Wave 0 では両者を `public` で揃える。
- 新たに npm registry(npmjs.com)等への公開は行わない。全パッケージ名は `@nerima-games/*` スコープであり、GitHub Packages の scoped registry 運用とそのまま合致する(この点は変更なし)。

**各リポジトリの `package.json` を書き換える必要がある。** §0 が確認した通り、確認できた15リポジトリ全部(`mc-kernel` を含む)がまだ `access: "restricted"` のままであり、これは「既に正しい設定が入っている」という旧稿の前提が現実と一致しなくなったことを意味する。目標値は次の通り(PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」 と同一):

```json
"publishConfig": {
  "registry": "https://npm.pkg.github.com",
  "access": "public"
}
```

## 3. CI publish ジョブの設計(2026-08-30 改訂: kernel の detect/publish/tag 形に統一)

**この節は当初 changesets/action ベースの "Version Packages" PR 自動生成フローを前提としていたが、
Wave 0 でそれを覆し、`mc-kernel` が既に実運用している detect → publish → tag の3ジョブ構成
(`.github/workflows/release.yaml`)にすべての対象リポジトリを揃える。** 上書きされる記述は
旧稿の §3.1〜§3.3(changesets/action 呼び出し1本で publish 判定まで済ませる設計)であり、
理由は publish 前の再検証(§3.3、下記)を満たすのが kernel 形だけだったためである。
workflow-templates/release.yml は kernel の `origin/main` の `release.yaml` をそのままコピーした
ものであり、以下はその内容の解説にとどめる。差分の唯一の例外は `mc-compose`
(publish job の `pnpm package:verify` 行を持たない。§3.3参照)。

### 3.1 3ジョブ構成

`push` イベント(`branches: [main]`)1本のトリガーで、以下の3ジョブが順に走る。

1. **`detect`**(5分)。Node/pnpm のセットアップを一切行わない、判定専用のジョブ。
   `git show "${{ github.event.before }}:package.json"` で直前コミットの `version` を読み、
   現在の `package.json#version` と比較する。変わっていなければ `changed=false` を出力して
   後続ジョブを起動させない。「初回 push(`before` が全ゼロ SHA)」は明示的にスキップする
   (`if: github.event.before != '0000000000000000000000000000000000000000'`)。
   `Node/pnpm を使わない判定専用ジョブ` は、判定と公開を1ジョブに融合していた旧設計で
   「公開しないと正しく判断した push」が `actions/setup-node` の `cache: pnpm` post-step で
   キャッシュ対象なしエラーを出し、**判断が正しいのに赤くなる CI** を生んでいた反省による分離
   (kernel の release.yaml 冒頭コメント参照)。
2. **`publish`**(20分。`needs: detect`、`if: needs.detect.outputs.changed == 'true'`)。
   `permissions: { contents: read, packages: write }`。§3.2 の認証で
   `nix develop --command pnpm verify` と `nix develop --command pnpm package:verify`
   を**再実行してから** `nix develop --command pnpm publish --no-git-checks` を呼ぶ(§3.3)。
3. **`tag`**(5分。`needs: [detect, publish]`、`permissions: { contents: write }`)。
   publish が成功した後にのみ `git tag "v<version>" <sha> && git push origin "v<version>"` を行う。
   publish より前にタグを打たない設計は、「タグは付いているが実際には公開されていない」状態を
   防ぐため(kernel の release.yaml コメント: publish 前にタグを打つ設計だった過去、
   1つのタグに対して19個のバージョンが公開されるという事故が起きている)。

`changesets/action` は使わない。version bump の作成(`pnpm changeset version` の実行と
`main` への反映)自体は §1 の changesets ワークフローに残るが、それを自動 PR 化する仕組みは
この org には存在せず、maintainer が手元で `pnpm changeset version` を実行してコミット・push
する運用になる。これは §1.3 の「"Version Packages" PR 自動生成」という記述との食い違いであり、
本書はこの食い違いを本節の書き換えでは解消していない(§1 は本タスクのスコープ外。
実際の運用手順を書く場合は §1.3 も合わせて見直すこと)。

### 3.2 認証

- 公開は同一 organization 内の GitHub Packages npm registry への publish であるため、**GitHub Actions が各ワークフロー実行に自動発行する組み込みの `GITHUB_TOKEN` のみで完結する。** 別途 Personal Access Token や `NPM_TOKEN` のような追加シークレットの発行・登録は不要である。
- `publish` ジョブで `actions/setup-node` の `registry-url: https://npm.pkg.github.com` を指定し、`pnpm publish` ステップの環境変数に `NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` を渡す。GitHub Packages npm registry は、同一 org 内のリポジトリからのワークフローであれば `GITHUB_TOKEN` に `packages: write` パーミッションを付与することで書き込み(公開)を許可する仕組みになっており、これは npm.pkg.github.com に特有の挙動である(npmjs.com など外部レジストリでは通用しない)。
- ワークフロー全体の `permissions` は `contents: read` のみ(トップレベル)。`publish` ジョブだけがジョブ単位で `packages: write` を追加する。`tag` ジョブは publish 後にタグを push するため `contents: write` を持つが `packages` は持たない。ジョブ単位で最小権限を割り当てる設計は、`detect` ジョブが Node/pnpm を一切呼ばないことと同じ「必要なジョブにだけ必要な権限を持たせる」思想に基づく。

### 3.3 何を公開するか、公開前に何を再検証するか

- 対象は変更のあった 1 パッケージのみ(単一パッケージリポジトリのため、リポジトリ = パッケージが 1:1)。`pnpm publish --no-git-checks` を、該当リポジトリの `package.json#files` の範囲(dist 公開形なら `["dist", "LICENSE", "README.md"]`。PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」)で実行する。
- **publish 前に `pnpm verify` と `pnpm package:verify` を必ず再実行する。** ブランチ保護が要求する `ci.yaml` の成功だけに頼らない理由は、publish は不可逆(一度取られたバージョン番号はレジストリ上で再利用できない)なため、`ci.yaml` が担う検証を publish ジョブ側でも独立に繰り返す(kernel の `release.yaml` コメント: "The same package checks the branch protection runs, repeated here because publishing is irreversible")。この再検証こそが、changesets/action 単体に publish を任せる旧設計(§1.3参照)では満たせなかった要件である。
- **`mc-compose` はこの節の唯一の例外。** `pnpm package:verify` を持たない(PACKAGE_STANDARD.md「package.json の必須フィールドとスクリプト」の通り dist を持たないため)ので、publish ジョブの検証ステップは `pnpm verify` のみになる。
- タグ(`v<version>`)と GitHub Release の作成は §3.1 の `tag` ジョブが担う。GitHub Release 本文の自動生成(CHANGELOG からの抜粋など)は必須要件ではない。

## 4. 0.x → 1.0.0 昇格ポリシー(旧ゲートの廃止)

### 4.1 廃止する仕組み

これまで想定されていた「`api-lock.md` が 4 週間変更されなければ API は凍結されたとみなし、1.0.0 に昇格する」という**日数計測ベースの自動ゲートは廃止する**。`api-lock.md` というファイル自体も本セッションで廃止されており、詳細は `API_STANDARD.md` を参照すること(本ドキュメントでは再掲しない)。

### 4.2 新しい昇格ポリシー: 人間による裁量判断

1.0.0 への昇格は、**自動化された指標や計測期間による代替ゲートを設けず、maintainer(take)による裁量判断のみで行う。** これは意図的な設計であり、次の点を明確にしておく:

- 「〇〇日間 API 変更なし」「利用実績が〇件」のような定量的な代替基準は導入しない。そのような基準を新設する提案自体を行わない。
- 判断材料として maintainer が何を見るかは都度異なってよい(上位階層からの利用実績、破壊的変更の落ち着き具合、他の維持コストなど)。基準を事前にすべて明文化することを求めない。
- Terraform 定義ファイル `repos_nerima_games.tf` の冒頭コメントが、この昇格モデルの一次情報源(authoritative source)である:

  > 構築モデル: 下から順に完成させ、GitHub Packages に公開し、上の階層は固定バージョンで参照する。各リポジトリは上の階層が消費して動作確認するまで 0.x、確認後 1.0.0 に昇格する。

  すなわち、「上の階層(依存する側)が実際にそのパッケージを消費し、動作確認を終える」ことが昇格の実質的なトリガーだが、それをもって自動的に 1.0.0 へ上げるわけではなく、その確認結果を踏まえて maintainer が 1.0.0 昇格の changeset(`major` bump)を書く、という運びになる。
- 1.0.0 への昇格自体も、通常の changeset ワークフロー(§1)に乗せる。昇格 PR は `pnpm changeset` で `major` を選択し、変更理由(「upper tier である `mc-worldgen` が `mc-kernel` を消費し、動作確認が完了したため」等)を changeset の説明文に明記する。

## 5. Tier に沿ったリリースの伝播順序(ripple order)

`mc-kernel` のような下位階層(Tier1)で破壊的変更が入った場合、それを消費する上位階層(Tier2 → Tier3 → Tier4)へ順に反映していく必要がある。この際のリリース順序は、依存関係グラフに従う。

- Tier1(安定ライブラリ): `mc-kernel` / `mc-noise` / `mc-meshing` / `mc-physics` / `mc-save` / `mc-audio`
- Tier2(基盤): `mc-worldgen` / `mc-sim` / `mc-render` / `mc-playground-kit`
- Tier3(体験モジュール): `mx-gameplay` / `mx-redstone` / `mx-ui` / `mx-multiplayer`
- Tier4(合成): `mc-compose`

具体的な依存グラフ(どのリポジトリがどのリポジトリに依存するかの詳細)は `DEPENDENCY_POLICY.md` を参照し、本ドキュメントでは再掲しない。リリース運用上守るべき原則のみ述べる:

1. **下位 Tier が先に安定・公開してから、上位 Tier がそれを取り込む。** Tier1 のある 1 パッケージに破壊的変更が入った場合、まず Tier1 内でその変更を changeset(`major` または `minor`、影響範囲に応じて)としてリリースし、GitHub Packages に公開する。
2. **上位 Tier は固定バージョンで参照する。** 上位 Tier のリポジトリは、下位 Tier の新バージョンを取り込む際に、依存先を追随させる changeset を追加してリリースする。この「取り込みと動作確認」が完了したことをもって、下位 Tier 側の 1.0.0 昇格判断(§4.2)の材料になる。
3. **同一 Tier 内は並行してよい。** 同じ Tier に属する複数リポジトリ間で直接の依存がない限り、リリース順序を Tier 内で厳密に決める必要はない。
4. **Tier をまたいで巻き戻すような依存(上位 Tier のリリースを待ってから下位 Tier をリリースする、など)は原則として作らない。** 依存の向きは常に下位 → 上位であり、リリースの ripple もその方向にのみ流れる。

## 6. まとめ

| 項目 | 方針 |
|---|---|
| バージョニング / CHANGELOG | `@changesets/cli` を全 15 パッケージに導入。PR ごとに `.changeset/*.md` を追加する(§1.2)。**"Version Packages" PR の自動生成(§1.3)は実装されていない** — 実際の運用は maintainer が手元で `pnpm changeset version` を実行し、bump 済みの `package.json`/`CHANGELOG.md` を `main` へ push する形で、それが §3 の `detect` ジョブへの入力になる(§3 参照) |
| 公開先 | GitHub Packages(`https://npm.pkg.github.com`, `access: "public"`。2026-08-30 に `restricted` から改訂)。各リポジトリの `package.json#publishConfig.access` を `public` へ書き換える必要がある(§2) |
| CI publish | `mc-kernel` が実運用する detect → publish → tag の3ジョブ構成(`.github/workflows/release.yaml`、`workflow-templates/release.yml` が同一内容をコピー)に統一。`detect` が `package.json#version` の変更を判定し、`publish` が `pnpm verify && pnpm package:verify` を再実行してから公開し、`tag` が公開後に `v<version>` を打つ。認証は組み込み `GITHUB_TOKEN`(`publish` ジョブのみ `packages: write`)、追加シークレット不要(§3) |
| 0.x → 1.0.0 昇格 | 旧・日数ベースの自動凍結ゲート(`api-lock.md` 4 週間ルール)は廃止。maintainer(take)による裁量判断のみで昇格する。代替の自動ゲートは設けない |
| リリース伝播順序 | Tier1(安定ライブラリ)→ Tier2(基盤)→ Tier3(体験モジュール)→ Tier4(合成)の依存方向に沿って ripple させる。詳細な依存グラフは `DEPENDENCY_POLICY.md` を参照 |

関連ドキュメント: `API_STANDARD.md`(API lock 廃止の詳細)、`DEPENDENCY_POLICY.md`(Tier 間依存グラフの詳細)。
