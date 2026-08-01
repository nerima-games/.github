# リリース標準

nerima-games organization 配下の TypeScript / Effect-ts パッケージ群における、バージョニング・CHANGELOG 生成・公開(publish)・0.x → 1.0.0 昇格の統一ルールを定める。

対象は `mc-dev-meta` を除く 15 リポジトリ(`mc-kernel` / `mc-noise` / `mc-meshing` / `mc-physics` / `mc-save` / `mc-audio` / `mc-worldgen` / `mc-sim` / `mc-render` / `mc-playground-kit` / `mx-gameplay` / `mx-redstone` / `mx-ui` / `mx-multiplayer` / `mc-compose`)。`mc-dev-meta` は `package.json` に `"private": true` が明示され、説明文にも "Never published." と書かれている開発用 pnpm workspace バインダーであり、公開パッケージではないためスコープ外とする。

## 0. 現状(このドキュメント作成時点で確認した事実)

以下は本ドキュメント作成にあたって実際にリポジトリを検証した結果であり、今回のスコープの前提となる。

- **リリース基盤は何もない。** 全 16 リポジトリを `grep` した結果、`.changeset/` ディレクトリ、`@changesets/cli` や `semantic-release` への依存、リポジトリ直下の `CHANGELOG.md` は一切存在しない(ヒットしたのは `node_modules` 配下のサードパーティ製パッケージの CHANGELOG のみ)。
- **`ci.yaml` に publish ジョブは存在しない。** 15 リポジトリすべての `.github/workflows/ci.yaml` を確認したが、`publish` / `registry` 相当のステップは 1 件もない。現行の CI は checkout → pnpm install → typecheck → lint → 依存関係ホワイトリスト検査 → API lock 検査 → test → coverage(99%ゲート) で完結しており、公開ステップの手前で止まっている。
- **`publishConfig` は既に GitHub Packages を指している。** `mc-kernel` / `mc-noise` / `mc-render` / `mx-ui` など確認した `package.json` はいずれも

  ```json
  "publishConfig": {
    "registry": "https://npm.pkg.github.com",
    "access": "restricted"
  }
  ```

  を持つ。つまり公開先の設定自体は先行して用意されているが、実際に `pnpm publish` が実行されたことは一度もない。
- **バージョンは全リポジトリ 0.x。** 観測範囲は `0.1.0`〜`0.2.8`(例: `mc-noise` 0.1.0, `mc-render` 0.1.1, `mc-sim` 0.1.24, `mx-gameplay` 0.1.36, `mc-kernel` 0.2.8, `mx-ui` 0.2.6)であり、1.0.0 に到達したリポジトリはまだない。
- **可視性は `public`。** `takeokunn/private-terraform/projects/github/repos_nerima_games.tf` で 16 リポジトリすべてが `visibility = "public"` と定義されている。private ではない点に注意する(GitHub Packages への公開設定・認証方針を検討する際の前提が変わる)。

## 1. Changesets 導入

### 1.1 採用パッケージ

全 15 対象リポジトリに [`@changesets/cli`](https://github.com/changesets/changesets) を `devDependency` として導入し、`changeset` コマンド群(`changeset add` / `changeset version` / `changeset publish` 相当の運用、後述の通り publish 自体は CI の GitHub Packages 公開ステップが担う)をバージョニングと CHANGELOG 生成の単一の入り口とする。

各リポジトリで以下を行う:

```bash
pnpm add -D @changesets/cli
pnpm changeset init
```

`pnpm changeset init` が生成する `.changeset/config.json` は、`access` を `restricted`(GitHub Packages の `publishConfig.access` と一致させる)、`baseBranch` を `main` に設定する。`changelog` 生成器は既定の `@changesets/changelog-git` ではなく、リポジトリ URL・PR 番号へのリンクを含む `@changesets/changelog-github` を使うことを推奨する(GitHub 上でリポジトリを跨いだレビューがしやすくなるため)。

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

## 2. 公開先: GitHub Packages(restricted)の正式化

既存の `publishConfig`(`registry: https://npm.pkg.github.com`, `access: "restricted"`)を、単なる先行設定ではなく **正式な公開先ポリシー** として確認・固定する。理由:

- 全リポジトリの `publishConfig` が既にこの設定で揃っており、変更コストがかからない。
- `access: "restricted"` は GitHub Packages 上でのパッケージ可視性を org メンバー(または明示的に許可されたチーム)に限定する設定であり、リポジトリ自体の GitHub 可視性が `public`(Terraform 定義より)であっても、パッケージの取得は npm レベルで別途 org 内アクセスに絞られる。リポジトリが public であることと、パッケージが restricted であることは独立した設定であり、両立する。
- 新たに npm registry(npmjs.com)等への公開は行わない。全パッケージ名は `@nerima-games/*` スコープであり、GitHub Packages の scoped registry 運用とそのまま合致する。

各リポジトリの `package.json` に変更は不要(既に正しい設定が入っている)。今回追加するのは、この設定を実際に使って CI から `pnpm publish` を実行する仕組みだけである。

## 3. CI publish ジョブの設計

現状どの `ci.yaml` にも publish ステップは存在しない。以下の内容で新設する。

### 3.1 トリガー条件

- `push` イベントかつ `branches: [main]` かつ、**変更差分に `package.json#version` の変更が含まれる場合**にのみ実行する。実務上は、changesets の "Version Packages" PR がマージされた瞬間がこれに当たる(§1.3)。
- 判定方法は次のいずれか(リポジトリ実装時に選択):
  - `changesets/action` の `published` / `publishedPackages` 出力を使い、そのジョブ内で直接 publish する(推奨。changesets 公式アクションが version bump commit の検出と publish 実行を一体で扱えるため、version 変更検出のための追加スクリプトが不要)。
  - もしくは既存の `ci` ジョブとは別ジョブとして `release` ジョブを切り出し、`git diff HEAD^ HEAD -- package.json` で `version` 行の差分有無を見て条件分岐する。
- 通常の feature PR やドキュメントのみの push では発火しない。既存の `ci` ジョブ(typecheck / lint / test / coverage 等)とは独立したジョブとして追加し、既存ゲートの実行内容・タイムアウトには影響を与えない。

### 3.2 認証

- 公開は同一 organization 内の GitHub Packages npm registry への publish であるため、**GitHub Actions が各ワークフロー実行に自動発行する組み込みの `GITHUB_TOKEN` のみで完結する。** 別途 Personal Access Token や `NPM_TOKEN` のような追加シークレットの発行・登録は不要である。
- 具体的には、ワークフロー内で `actions/setup-node@v6` の `registry-url: https://npm.pkg.github.com` を指定し、publish ステップの環境変数に `NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` を渡す。GitHub Packages npm registry は、同一 org 内のリポジトリからのワークフローであれば `GITHUB_TOKEN` に `packages: write` パーミッションを付与することで書き込み(公開)を許可する仕組みになっており、これは npm.pkg.github.com に特有の挙動である(npmjs.com など外部レジストリでは通用しない)。
- ワークフローの `permissions` は既定で `contents: read` のみになっている(`ci.yaml` のコメントにある通り、fork PR からの実行を考慮した設定)。publish ジョブでは明示的に `permissions: { packages: write, contents: read }` を追加する。fork PR ではこの拡張パーミッションが渡らないため、publish ジョブは事実上 `main` ブランチへの push(= 権限のある maintainer によるマージ)のみで動く。

### 3.3 何を公開するか

- 対象は変更のあった 1 パッケージのみ(単一パッケージリポジトリのため、リポジトリ = パッケージが 1:1)。`pnpm publish --no-git-checks` を、該当リポジトリの `package.json` が定義する `files` フィールドの範囲(`index.ts` / `domain` / 各リポジトリ固有のディレクトリ / `tsconfig.base.json` / `LICENSE` / `README.md` など、確認した範囲では実装ファイルをビルドせずソースのまま公開する構成になっている)で実行する。
- publish 前に既存の `ci` ジョブと同等の検証(typecheck / lint / test)を再実行してから公開するか、`ci` ジョブの成功を `needs:` で待って publish するかは各リポジトリの実装に委ねるが、**未検証のコミットを publish しない**ことを必須要件とする。
- 公開後、GitHub Release の作成(タグ `v<version>` + CHANGELOG からの抜粋)も同じジョブで行うことを推奨するが、必須要件ではない。

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
| バージョニング / CHANGELOG | `@changesets/cli` を全 15 パッケージに導入。PR ごとに `.changeset/*.md` を追加し、"Version Packages" PR を経て bump・CHANGELOG 生成する |
| 公開先 | GitHub Packages(`https://npm.pkg.github.com`, `access: "restricted"`)。既存 `publishConfig` を正式方針として確認 |
| CI publish | `main` への push かつ `package.json#version` 変更時のみ発火する新規ジョブ。認証は組み込み `GITHUB_TOKEN`(`packages: write`)のみ、追加シークレット不要 |
| 0.x → 1.0.0 昇格 | 旧・日数ベースの自動凍結ゲート(`api-lock.md` 4 週間ルール)は廃止。maintainer(take)による裁量判断のみで昇格する。代替の自動ゲートは設けない |
| リリース伝播順序 | Tier1(安定ライブラリ)→ Tier2(基盤)→ Tier3(体験モジュール)→ Tier4(合成)の依存方向に沿って ripple させる。詳細な依存グラフは `DEPENDENCY_POLICY.md` を参照 |

関連ドキュメント: `API_STANDARD.md`(API lock 廃止の詳細)、`DEPENDENCY_POLICY.md`(Tier 間依存グラフの詳細)。
