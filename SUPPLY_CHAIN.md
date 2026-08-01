# nerima-games サプライチェーン基準

nerima-games org の CI が、何を信頼し何を信頼しないかを決めた文書です。
調査日は 2026-08-01、対象は TypeScript / Effect-ts の16リポジトリ
(`mc-audio` `mc-compose` `mc-dev-meta` `mc-kernel` `mc-meshing` `mc-noise`
`mc-physics` `mc-playground-kit` `mc-render` `mc-save` `mc-sim` `mc-worldgen`
`mx-gameplay` `mx-multiplayer` `mx-redstone` `mx-ui`)です。すべて public リポジトリで、
fork からの `pull_request` が無条件にこの文書の対象ワークフローを走らせます。

[PACKAGE_STANDARD.md](PACKAGE_STANDARD.md) はリポジトリの外形を、[CODING_STANDARD.md](CODING_STANDARD.md) はコードの中身を決めます。
リポジトリ間・外部パッケージの依存を許可するかどうかは [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md) の対象で、
本書は依存を「許可するか」ではなく「許可した依存とアクションをどう固定し、どう検知するか」だけを扱います。
自己レビュー・自己マージの手順は [REVIEW_STANDARD.md](REVIEW_STANDARD.md) が別途定めます。ここでは触れません。
**ブランチ保護もこの文書の対象外です**。理由と参照先は最後の節にあります。

## 決定事項の一覧

**脅威モデル**：守る対象は CI トークンの機密性と、GitHub Packages に公開する npm パッケージの完全性です。
姉妹パッケージ (`nixos-configuration` 系列や `paredit-cli` にある) Nix ビルドキャッシュや Cachix への書き込み権限は、
この org の CI に存在しないため対象に含みません。メンテナアカウントの掌握後の防御は設計目標に含めません。

**アクションの固定**：`uses:` は40文字の commit SHA で固定し、`# vX` を末尾コメントに併記します。
現状は `pnpm/action-setup` だけがこの形になっており、`actions/checkout` `actions/setup-node` `actions/upload-artifact`
の3つは可変な major タグ（`@v6` など）止まりです。この3つを SHA 固定へ移行することが本書の主要な要求です。

**権限**：全16リポジトリの `ci.yaml` はすでにワークフロー先頭で `permissions: contents: read` を宣言しています。
これは維持すべき既存の基準線であり、本書が新たに要求するものではありません。

**secrets**：全16リポジトリの `ci.yaml` を横断して grep した結果、`secrets.` を参照する行は1つもありません。
これも維持すべき既存の基準線です。

**Dependabot**：org のどのリポジトリにも `dependabot.yml` が存在しません。全16リポジトリに追加し、
`github-actions` エコシステムを毎週の頻度で有効にします。`npm` エコシステムも合わせて追加します。

**ブランチ保護**：Terraform で外部管理されています。本書では再定義しません。

## 脅威モデル

この org はネットワークサービスを運用しておらず、CI が公開しているのは GitHub Packages 上の npm パッケージだけです。
守るべき対象は2つに絞れます。

1. **CI トークンの機密性**。`GITHUB_TOKEN` が、fork からの `pull_request` で実行されるコードに渡らないこと。
2. **公開パッケージの完全性**。`@nerima-games/mc-kernel` のような GitHub Packages 上のパッケージが、
   タグの指すツリーと一致すること。各リポジトリの `package.json` は
   `publishConfig: { registry: "https://npm.pkg.github.com", access: "restricted" }` を持ち、
   `.npmrc` で `@nerima-games:registry` を同じ registry に固定しています(`mx-ui/.npmrc` 等で確認済み)。
   ただし現時点でどのリポジトリの `ci.yaml` にも `npm publish` 相当のステップは存在せず、公開は手元から行われています。
   CI がこの資格情報を扱う日が来た時点で、本書はそのジョブに対する `permissions: packages: write` の最小化と
   secrets の扱いを追記します。

nerima-lisp org の同名文書と異なり、Cachix や `flake.lock` はこの脅威モデルに含めません。
`flake.nix` / devenv はローカル開発シェルのためだけに存在し(`PACKAGE_STANDARD.md` 参照)、
どの `ci.yaml` も Nix ステップを持たず pnpm + Node.js のみで動くため、CI 側に守るべき Nix バイナリキャッシュがありません。

| 経路 | 具体的な形 | 主な対策 |
|---|---|---|
| 改竄されたアクション | 上流が可変タグを別の commit へ付け替える | `uses:` の SHA 固定 |
| fork PR での secrets 漏洩 | `pull_request` で secrets を参照するステップが存在する | secrets 不使用（すでに達成、維持） |
| 既定より広い権限での実行 | ワークフロー先頭の `permissions:` 宣言漏れ | `contents: read` の宣言（すでに達成、維持）+ ジョブ単位の最小権限（後述） |
| 依存の既知脆弱性 | `effect` や `vitest` など npm 依存の CVE | Dependabot `npm` エコシステム |
| アクション自体の既知脆弱性 | `actions/checkout` 等の CVE | Dependabot `github-actions` エコシステム |

## すでに満たしている基準

`mc-kernel` `mx-ui` `mc-audio` `mc-dev-meta` の `ci.yaml` を読んで確認した内容で、残り12リポジトリも同型です。

**`permissions: contents: read` をワークフロー先頭で宣言済み。**
4リポジトリすべてが、ジョブより前の階層で以下を宣言しています。

```yaml
permissions:
  contents: read
```

コメントも4リポジトリで共通です。「public リポジトリなので fork PR がこのワークフローを実行する。
ここには書き込み権限を要するステップがなく、宣言しなければ org デフォルト（Terraform 管理外）を継承する」という理由づけが書かれています。
これは維持してください。新しいワークフローファイルを追加するときも、まずこの宣言から書きます。

**secrets を一切参照していない。**
`grep -rn "secrets\." */.github/workflows/*.yaml` を全16リポジトリに対して実行し、ヒットはゼロでした。
CI トークンの機密性という脅威モデルの1つ目に対して、参照する secrets 自体が存在しないという最も強い形で応えています。
これは「secrets を安全に扱う」ルールを追加する前の基準線として維持し、将来 secrets を導入する変更は本書の改訂を伴わせます。

## アクションの固定

**現状は部分的です。** `pnpm/action-setup` はすでに commit SHA で固定されており、これが目指す形です。

```yaml
- name: Setup pnpm
  # Pinned to a commit, not the mutable v4 tag: this is a third-party action
  # and a tag can be repointed at new code without any change here.
  uses: pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1 # v4
```

一方 `actions/checkout` `actions/setup-node` `actions/upload-artifact` の3つは、`mc-kernel` `mx-ui` `mc-audio` `mc-dev-meta`
を含む全リポジトリで可変な major タグ止まりです（`mc-compose` は `@v4` のままで、他は `@v6` — タグの可変性自体が
リポジトリ間でバージョンが揃わなくなる原因でもあります）。GitHub 公式アクションだから安全という理由にはなりません。
タグは上流が任意のタイミングで別の commit へ付け替えられる可変参照であり、`@vX` は「vX という名前のタグが指す
その時点の commit」を毎回信頼するという意味だからです。

**`actions/checkout` の before/after** (`mc-kernel/.github/workflows/ci.yaml` の該当行):

```yaml
# Before（可変タグ止まり。タグの指す commit は上流が後から変更できる）
- name: Checkout
  uses: actions/checkout@v6
```

```yaml
# After（commit SHA 固定 + バージョンの手がかりとしてタグ名をコメントに残す）
- name: Checkout
  uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6
```

`actions/setup-node@v6` は `249970729cb0ef3589644e2896645e5dc5ba9c38 # v6` へ、
`actions/upload-artifact@v6` は `b7c566a772e6b6bfb58ed0dc250532a479d7789f # v6` へ、同じ形式で置き換えます。
（SHA は `git ls-remote --tags` で各アクションの `v6` タグから直接確認したものです。値を機械的にコピーせず、
実際に取得して確認してください。）

**目指す形は `mc-kernel` にすでに存在します。** `main` にはまだマージされていませんが、
`mc-kernel` の `feat/kernel-api-hardening` ブランチ（worktree: `mc-kernel/.worktrees/feat-kernel-api-hardening`）に
`.github/workflows/docs.yaml` があり、この文書が求める形をすでに実践しています。

```yaml
permissions: {}

jobs:
  build:
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          persist-credentials: false
      - name: Set up Python
        uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5
  deploy:
    needs: build
    permissions:
      pages: write
      id-token: write
```

一般化すべき点は3つです。

1. すべての `uses:` が commit SHA + `# vX` コメントの形。`checkout` だけでなく `setup-python` (`ci.yaml` では `setup-node`) も同様。
2. ワークフロー先頭は `permissions: {}` まで絞り、必要な権限は**ジョブ単位**で書き足す（`build` は `contents: read` だけ、
   `deploy` は `pages: write` / `id-token: write` だけ）。`ci.yaml` は単一ジョブなので、
   先頭の `permissions: contents: read` をそのままジョブレベルへ複製する形で足ります（`{}` へ絞る効果は薄いですが、
   複数ジョブのワークフローを今後追加する際はこの分離を踏襲してください）。
3. `actions/checkout` に `with: persist-credentials: false` を足す。デフォルトでは checkout 後も
   `GITHUB_TOKEN` が `.git/config` の `http.https://github.com/.extraheader` に残り、以降のステップ
   （lint、test、任意の `pnpm` スクリプト）から読める状態になります。この org のジョブは push 権限を必要としないため、
   残す理由がありません。

この3点を全16リポジトリの `ci.yaml`（および `mc-kernel` が持つ `docs.yaml` 相当のワークフローがあれば同様に）へ適用してください。
`docs.yaml` は該当ブランチのままで問題ありません。パターンを ``ci.yaml`` 側へ持ってくることが目的です。

### 追加された信頼済みプロバイダ: Nix / Cachix(2026-08-01)

oxlint を Nix devShell 経由に切り替えたこと(PACKAGE_STANDARD.md)により、CI に2つの新しいサードパーティ
アクションが加わりました。両方とも commit SHA 固定です。

```yaml
- uses: DeterminateSystems/nix-installer-action@ef8a148080ab6020fd15196c2084a2eea5ff2d25 # v22
- uses: cachix/cachix-action@5f2d7c5294214f71b873db4b969586b980625e71 # v17
```

いずれも `.github/actions/nix-setup/`(`templates/actions/nix-setup/` からコピーした composite action)の中でのみ使う。
`CACHIX_AUTH_TOKEN` は fork PR(`pull_request` イベント)では push できない設定になっており
(`nix-setup/action.yml` の `Resolve Cachix mode` ステップ参照)、これは `nerima-lisp/.github` の同名アクションと
同じ安全策です。キャッシュは16リポジトリ共有の単一キャッシュ `takeokunn-nerima-games`
(`takeokunn/private-terraform` の `projects/cachix/caches.tf` で作成、`projects/github/repos_nerima_games.tf` で
各リポジトリへ `CACHIX_CACHE` 変数として配線済み)。nerima-lisp のリポジトリ単位キャッシュとは異なる設計判断で、
理由は16リポジトリの devShell が(リポジトリ固有のビルド成果物を持たず)ほぼ同一内容だから。

## Dependabot

**現状、org のどのリポジトリにも `dependabot.yml` がありません。** `find` を全16リポジトリに対して実行し確認済みです。
アクションの SHA 固定は「今ある参照を固定する」対策であり、固定した先が古くなったまま気づかれないことを防ぐ仕組みが別に要ります。
それが Dependabot です。全16リポジトリに `.github/dependabot.yml` を追加し、以下を最低限のエントリとします。

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
```

**`github-actions` は必須。** 本書がまさに固定を要求している3つのアクション（と `pnpm/action-setup`）の更新を、
SHA 固定後も追従可能にする唯一の手段です。SHA 固定は「現在の参照が動かない」ことを保証しますが、
「新しいバージョンに気づく」ことは保証しません。両方揃って初めて固定が更新可能な固定になります。

**`npm` も追加する。** 除外する理由を探しましたが見つかりませんでした。全16リポジトリが `effect` `vitest` `oxlint`
などの実行時・開発時 npm 依存を持ち、うち15リポジトリ（`mc-dev-meta` を除く）は `pnpm-lock.yaml` をコミットしています
(`git ls-files pnpm-lock.yaml` で確認済み)。コミットされたロックファイルがある以上、Dependabot がバージョンとハッシュの
両方を検証した上で PR を作れる状態が最初から整っており、追加しない理由の方が説明を要します。

`mc-dev-meta` だけは例外です。`ci.yaml` 自身のコメントが説明する通り、`pnpm-lock.yaml` は意図的に `.gitignore` されています
（ワークスペースルートのロックファイルが gitignore 対象のパッケージ群を記述してしまうため、コミット可能な成果物ではないという判断)。
Dependabot はロックファイルがなくても `package.json` の caret 範囲に対して PR を作成できるため、
このリポジトリにも同じ `npm` エントリを追加してください。ロックファイルがないことは Dependabot 追加を妨げません
（`pnpm install --frozen-lockfile` を使わないことで生じる「CI がある日 devDependencies の新版だけで赤くなる」リスクは
`ci.yaml` のコメントがすでに引き受けている前提であり、本書はその判断を変更しません）。

## ブランチ保護は Terraform 管理下にあり、本書の対象外です

`main` の署名必須化や force-push 禁止は、この `.github` リポジトリのどのファイルでも定義しません。
`/Users/take/ghq/github.com/takeokunn/private-terraform/projects/github/rulesets.tf` の
`github_repository_ruleset.nerima-games-public-main` が、全16リポジトリに対して
`required_signatures = true` と `non_fast_forward = true` を適用しています。

この ruleset は意図的に PR 承認必須のルールを持ちません。GitHub は自分自身の PR への承認（self-approval）を許可せず、
この org はメンテナ1人による運用のため、承認必須のルールを足すと最初の PR からマージ不能になります。
何を確認すれば自己マージしてよいかは [REVIEW_STANDARD.md](REVIEW_STANDARD.md) が定める領域であり、
Terraform のルールとして表現するものではありません（`rulesets.tf` 自身のコメントも同じ理由を述べています）。

本書がブランチ保護の内容を重複して書かない理由は、定義が二箇所に分散すると、
一方だけを変更して整合性が崩れる事故を避けるためです。ブランチ保護を変更する必要があるときは、
上記の Terraform ファイルを直接読み、変更してください。
