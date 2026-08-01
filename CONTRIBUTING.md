# nerima-games への貢献

このファイルは org 全体のデフォルトです。GitHub は、自前の `CONTRIBUTING.md` を持たない
nerima-games 配下の全リポジトリに対してこのファイルを表示します。個々のリポジトリ固有の手順は
そのリポジトリの `docs/` に書いてください。ここには書きません。

## この開発体制について

nerima-games は人間のメンテナー1人と AI コーディングエージェントによって開発されています。
チームレビューを前提にした運用ではなく、**自己レビュー・自己マージが通常の運用形態**です。
何を自己レビューで確認するか、何を確認したら自分の PR を自分でマージしてよいかは
[REVIEW_STANDARD.md](REVIEW_STANDARD.md) に定めています。先に読んでください。

## 標準文書

リポジトリの外形やコードの中身に関する具体的なルールは、以下の12個の文書に分かれています。
このファイルはそれらの要約ではなく入り口です。内容はリンク先を参照してください。

| 文書 | 扱う範囲 |
|---|---|
| [PACKAGE_STANDARD.md](PACKAGE_STANDARD.md) | リポジトリのディレクトリ構成、`package.json` の必須フィールド、tsconfig 構成 |
| [CODING_STANDARD.md](CODING_STANDARD.md) | ソースコードの書き方 |
| [API_STANDARD.md](API_STANDARD.md) | 公開 API の設計と破壊的変更の扱い |
| [TEST_STANDARD.md](TEST_STANDARD.md) | テストの書き方、`pnpm verify` の構成 |
| [DOCS_STANDARD.md](DOCS_STANDARD.md) | `docs/` フォルダに何を書くか |
| [PERFORMANCE_STANDARD.md](PERFORMANCE_STANDARD.md) | パフォーマンス基準と計測方法 |
| [DEPENDENCY_POLICY.md](DEPENDENCY_POLICY.md) | リポジトリ間・外部パッケージの依存許可 |
| [RELEASE_STANDARD.md](RELEASE_STANDARD.md) | バージョニングとリリース手順 |
| [SUPPLY_CHAIN.md](SUPPLY_CHAIN.md) | サプライチェーンセキュリティ |
| [REVIEW_STANDARD.md](REVIEW_STANDARD.md) | 自己レビュー・自己マージのチェックリスト |
| [GLOSSARY.md](GLOSSARY.md) | org 共通の用語集 |
| [DECISIONS.md](DECISIONS.md) | 過去の設計判断とその理由 |

迷ったときは、まず対象のリポジトリがどの標準に触れる変更かを考え、該当文書を読んでください。
複数の文書にまたがる場合(例: 新しい public API を追加しつつ依存を増やす)は、
それぞれの該当節を確認してください。

## PR を出す前に

```sh
pnpm verify   # typecheck && lint && test
```

`pnpm verify` は全リポジトリで共通のゲートです。これがローカルで通ることを確認してから
PR を出してください。詳細な構成は [TEST_STANDARD.md](TEST_STANDARD.md) を参照してください。

その他、PR を出す際の具体的なチェック項目は
[PULL_REQUEST_TEMPLATE.md](PULL_REQUEST_TEMPLATE.md) に従ってください。GitHub が PR 作成時に
自動でテンプレートとして挿入します。

## セキュリティ上の問題を見つけたら

公開の issue には書かないでください。[SECURITY.md](SECURITY.md) の手順に従ってください。
