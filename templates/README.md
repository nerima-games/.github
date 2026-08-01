<!--
TEMPLATE. Replace every PACKAGE with the repository name (e.g. mc-kernel),
fill in each bracketed/placeholder paragraph, and delete this header.

Section order and structure below were extracted directly from
mc-kernel/README.md and mc-physics/README.md (read 2026-08-01). Keep the
section order; omit a section only when it genuinely does not apply yet
(e.g. a brand-new repository with no public API yet omits 使い方), and do not
add new top-level sections without first checking whether an existing one
already fits.

Note what real nerima-games READMEs do NOT have: neither of the two read for
this template carries CI/license/docs badges at the top, and neither has a
"Contributing" or "Support" section (those live only in the org-wide
.github/CONTRIBUTING.md, not per-repo). Don't add either unless you have
observed the org convention change across more repositories than these two.
-->

# @nerima-games/PACKAGE

## 責務

このリポジトリが担う責務を 1〜3 文で書く。何をするかだけでなく、対象にしないもの
(参照実装 `takeokunn/ts-minecraft` との違いなど)も書けるとよい。

## 依存

`@nerima-games/*` のうちどれに依存するか(依存しないなら「なし」と明記する)。
依存する場合は理由も書く。DEPENDENCY_POLICY.md の Tier 構成(安定ライブラリ →
基盤 → 体験モジュール → 合成)に沿っているかを確認すること。

依存許可リストは `scripts/check-dependency-whitelist.ts` の
`REPOSITORY_POLICY` で機械的に強制する(PACKAGE_STANDARD.md)。このスクリプト
自体は全リポジトリ共通のテンプレートなので、冒頭の `REPOSITORY_POLICY` 定数
だけを書き換えてコピーし、それ以外の部分は変更しない。

## このリポジトリの位置づけ

| 関係 | リポジトリ |
| --- | --- |
| 親(依存先) | ここに列挙する。無ければ「なし」 |
| 子(依存元) | ここに列挙する。未確定なら「未確定」 |

DEPENDENCY_POLICY.md が定める Tier のうち、どの Tier に属するかをここで明記する。

## ドキュメント

**[docs/README.md](./docs/README.md) が索引。** DOCS_STANDARD.md が定める
必須ページ(README / architecture / responsibility / public-api / testing /
versioning / design-notes。凍結された参照実装からの移植がある場合は porting
も必須)をここに列挙する。

| ドキュメント | 内容 |
| --- | --- |
| [docs/architecture.md](./docs/architecture.md) | 4 階層アーキテクチャ上の自リポジトリの位置、依存グラフ |
| [docs/responsibility.md](./docs/responsibility.md) | 責務と、明示的な非スコープ |
| [docs/public-api.md](./docs/public-api.md) | 公開 API 全体 |
| [docs/testing.md](./docs/testing.md) | 検証要件・完成条件・カバレッジゲートの状態 |
| [docs/versioning.md](./docs/versioning.md) | 0.x → 1.0.0 方針、GitHub Packages への publish |
| [docs/design-notes.md](./docs/design-notes.md) | 設計原則、参照実装の既知の失敗の実測知見 |

## 開発

### セットアップ

```console
$ direnv allow          # flake.nix の devShell で nodejs_24 + corepack が入る
$ pnpm install
```

Nix を使わない場合は Node.js 24 以上と pnpm(`corepack` 推奨。`package.json` の
`packageManager` フィールドが版を pin している)を用意する。

### コマンド

| コマンド | 内容 |
| --- | --- |
| `pnpm typecheck` | `tsconfig.build.json` と `tsconfig.test.json` の両方を型検査 |
| `pnpm lint` | oxlint(このリポジトリ唯一の lint / format 設定) |
| `pnpm lint:fix` | oxlint の自動修正 |
| `pnpm test` | vitest(`@effect/vitest` の `it.effect` が主 API) |
| `pnpm test:watch` | vitest watch |
| `pnpm test:coverage` | カバレッジ計測 |
| `pnpm check:deps` | 依存ホワイトリスト + 循環検査 + 壁時計直読み禁止の検査 |
| `pnpm api:check` | `api-lock.md` が実際の公開 API と食い違えば非ゼロ終了 |
| `pnpm api:update` | `api-lock.md` を書き直す。公開面を変える PR は結果を同じ PR に含める |
| `pnpm verify` | 上記のうち CI(workflow-templates/ci.yml)と同じ内容をまとめて実行 |

## 使い方

公開 API の最小の使用例。1 コードブロック、20 行未満を目安にする。公開 API が
まだ無い場合(新規リポジトリの初期段階)はこのセクションごと省略する。

```typescript
import { /* ... */ } from '@nerima-games/PACKAGE'
```

## 現状

実装の進捗・既知の制約・保留事項を箇条書きで書く。完了していない設計判断や、
参照実装との既知の差分をここに書く。ビルド/publish の状態(未着手なら
「まだない」。RELEASE_STANDARD.md の changesets 導入後、実際に publish された
版があればそのバージョン)もここに含める。

## License

MIT
