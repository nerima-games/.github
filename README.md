# nerima-games/.github

org 全体の既定ファイルと、16 リポジトリが従う基準を置くリポジトリです。

GitHub は、ここに置いたコミュニティヘルスファイルを、それを持たない他のリポジトリの既定値として配信します。
そのため16リポジトリへ同じファイルを複製する必要はありません。

## 何がどこにあるか

基準は12文書に分かれています。リポジトリの外形を決めるものと、中身を決めるものと、運用を決めるものです。

### 外形と中身の基準

| ファイル | 役割 |
|---|---|
| [PACKAGE_STANDARD.md](PACKAGE_STANDARD.md) | リポジトリの外形。`src/` 構成、CI、Nix、3つの条件付きディレクトリ軸 |
| [CODING_STANDARD.md](CODING_STANDARD.md) | ソースコードの中身。oxlint規約、命名、domain/application分離、コミット規約 |
| [API_STANDARD.md](API_STANDARD.md) | 公開APIの設計。`src/index.ts` が公開面そのものであるという原則 |
| [TEST_STANDARD.md](TEST_STANDARD.md) | テスト方針。99%カバレッジゲート、既知の非適合リポジトリ |
| [DOCS_STANDARD.md](DOCS_STANDARD.md) | ドキュメント。`docs/` の必須ページ構成（内容は各リポジトリ管理のまま） |
| [PERFORMANCE_STANDARD.md](PERFORMANCE_STANDARD.md) | 性能。vitest benchの置き場と測り方、既存3リポジトリの独自基盤の扱い |

### 横断の基準

| ファイル | 役割 |
|---|---|
| [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md) | 4階層の依存グラフ、循環禁止、oxlintによる強制 |
| [RELEASE_STANDARD.md](RELEASE_STANDARD.md) | changesets導入、GitHub Packages公開、リリース波及順序 |
| [SUPPLY_CHAIN.md](SUPPLY_CHAIN.md) | 脅威モデル、SHA固定、permissions、Dependabot |
| [REVIEW_STANDARD.md](REVIEW_STANDARD.md) | セルフレビュー/AIエージェント委譲モデル、Issueラベル体系 |
| [GLOSSARY.md](GLOSSARY.md) | 用語と識別子語彙の統一 |
| [DECISIONS.md](DECISIONS.md) | 決定記録の運用と、この標準化に関する決定の索引 |

### 適用のための道具

| ファイル | 役割 |
|---|---|
| [MIGRATION_RUNBOOK.md](MIGRATION_RUNBOOK.md) | 既存16リポジトリを基準へ寄せる作業指示書 |
| [CONFORMANCE.md](CONFORMANCE.md) | 適合チェックリストと現状の適合率 |
| `scripts/check-conformance.sh` | 適合を機械的に判定する |
| `workflow-templates/` | GitHubの「新しいワークフロー」画面に出るCI/リリーステンプレート |
| `templates/` | 各リポジトリへコピーする雛形（flake.nix、README、gitignore） |

### org 既定ファイル

| ファイル | 役割 |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | 基準の実務向け要約 |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | Contributor Covenant 2.1 |
| [SECURITY.md](SECURITY.md) | 脆弱性報告の窓口 |
| [SUPPORT.md](SUPPORT.md) | 質問先の案内 |
| `ISSUE_TEMPLATE/`、`PULL_REQUEST_TEMPLATE.md` | IssueとPRの雛形 |
| `profile/README.md` | github.com/nerima-games の公開プロフィール |

## どれから読むか

はじめて貢献するなら [CONTRIBUTING.md](CONTRIBUTING.md) だけで足ります。

リポジトリを1つ担当するなら [PACKAGE_STANDARD.md](PACKAGE_STANDARD.md) と [CODING_STANDARD.md](CODING_STANDARD.md) を読み、
コードを書くときに [API_STANDARD.md](API_STANDARD.md) と [TEST_STANDARD.md](TEST_STANDARD.md) を引きます。

PRを出す前には [REVIEW_STANDARD.md](REVIEW_STANDARD.md) のセルフレビューチェックリストを確認してください。

基準そのものを変えたいなら [DECISIONS.md](DECISIONS.md) を先に読んでください。すでに検討して捨てられた選択肢がそこに書いてあります。

## 適合状況を確認する

```sh
# 16リポジトリすべて
./scripts/check-conformance.sh ~/ghq/github.com/nerima-games

# 1つだけ
./scripts/check-conformance.sh ~/ghq/github.com/nerima-games mc-kernel
```

不適合が1つでもあれば終了ステータスが1になるので、そのままゲートに使える。現状の適合率は [CONFORMANCE.md](CONFORMANCE.md) に記録してある。

## 依存の向き

依存には4つの層がある。層の番号は下ほど小さく、依存は同じ層か下の層へのみ向く。定義と根拠は [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md) にある。

| 層 | 役割 | 所属 |
|---|---|---|
| Tier1 | 安定ライブラリ。内部依存ゼロ | `mc-kernel` `mc-noise` `mc-meshing` `mc-physics` `mc-save` `mc-audio` |
| Tier2 | 基盤 | `mc-worldgen` `mc-sim` `mc-render` `mc-playground-kit` |
| Tier3 | 体験モジュール。相互依存なし | `mx-gameplay` `mx-redstone` `mx-ui` `mx-multiplayer` |
| Tier4 | 合成 | `mc-compose` |
| 層外 | 開発ツール | `mc-dev-meta` |

## ブランチ保護・org設定について

このリポジトリはGitHubのコミュニティヘルスファイルと基準文書だけを持つ。ブランチ保護・リポジトリ可視性などのGitHub org設定そのものは
`takeokunn/private-terraform`（`projects/github/repos_nerima_games.tf`、`rulesets.tf`）でTerraform管理されており、ここでは扱わない。

## 基準を変えたいとき

該当する基準文書へのPull Requestとして提案する。基準を変えると16リポジトリに作業が波及するので、変更には移行手順を添える。
`scripts/check-conformance.sh` の判定も同じPRで更新する。

決定を覆すときは、[DECISIONS.md](DECISIONS.md) の該当記録を書き換えず、新しい記録を追加して古い方を置換済みにする。
