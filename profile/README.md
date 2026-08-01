# nerima-games

Minecraft クローンを TypeScript / Effect-ts でゼロから再実装するプロジェクトです。
16 個のリポジトリに分割し、4層の依存アーキテクチャで組み立てています。

## 4層アーキテクチャ

| 層 | 役割 | リポジトリ |
|---|---|---|
| Tier1 | 安定ライブラリ。org 内依存ゼロ | [mc-kernel](https://github.com/nerima-games/mc-kernel) · [mc-noise](https://github.com/nerima-games/mc-noise) · [mc-meshing](https://github.com/nerima-games/mc-meshing) · [mc-physics](https://github.com/nerima-games/mc-physics) · [mc-save](https://github.com/nerima-games/mc-save) · [mc-audio](https://github.com/nerima-games/mc-audio) |
| Tier2 | 基盤モジュール | [mc-worldgen](https://github.com/nerima-games/mc-worldgen) · [mc-sim](https://github.com/nerima-games/mc-sim) · [mc-render](https://github.com/nerima-games/mc-render) · [mc-playground-kit](https://github.com/nerima-games/mc-playground-kit) |
| Tier3 | 体験モジュール(互いに依存しない) | [mx-gameplay](https://github.com/nerima-games/mx-gameplay) · [mx-redstone](https://github.com/nerima-games/mx-redstone) · [mx-ui](https://github.com/nerima-games/mx-ui) · [mx-multiplayer](https://github.com/nerima-games/mx-multiplayer) |
| Tier4 | 合成 | [mc-compose](https://github.com/nerima-games/mc-compose) |
| 層外 | 開発用ワークスペース束ね役 | [mc-dev-meta](https://github.com/nerima-games/mc-dev-meta) |

依存は同じ層か、より下の層へのみ向かいます。`mc-kernel` は全リポジトリが依存できる共有語彙で、
逆に他のどのリポジトリにも依存しません。`mc-compose` は Layer 合成・フレームステージの単一の
全順序・セッションライフサイクルを持つ、唯一の Tier4 リポジトリです。

## リポジトリ一覧

| リポジトリ | 何をするものか |
|---|---|
| [mc-kernel](https://github.com/nerima-games/mc-kernel) | ブランデッド型・座標・ブロック能力フラグ・フレーム契約・Clock Port |
| [mc-noise](https://github.com/nerima-games/mc-noise) | シード決定論的ノイズ(PRNG・Perlin・fBm 合成) |
| [mc-meshing](https://github.com/nerima-games/mc-meshing) | チャンクデータからジオメトリバッファへの純粋変換、greedy meshing |
| [mc-physics](https://github.com/nerima-games/mc-physics) | Euler 積分と AABB 衝突解決 |
| [mc-save](https://github.com/nerima-games/mc-save) | バージョン付きセーブフォーマットと移行チェーン |
| [mc-audio](https://github.com/nerima-games/mc-audio) | サウンドキューレジストリ・BGM ステートマシン |
| [mc-worldgen](https://github.com/nerima-games/mc-worldgen) | バイオーム分類・地形生成・構造物・チャンクライフサイクル |
| [mc-sim](https://github.com/nerima-games/mc-sim) | エンティティ・インベントリ・時間・フレームループ |
| [mc-render](https://github.com/nerima-games/mc-render) | ポストプロセス・マテリアルポリシー・InputService |
| [mc-playground-kit](https://github.com/nerima-games/mc-playground-kit) | プレビュー起動用の開発ハーネス |
| [mx-gameplay](https://github.com/nerima-games/mx-gameplay) | 採掘・設置・アイテム使用・モブ・液体・乗り物・天候などのゲームルール |
| [mx-redstone](https://github.com/nerima-games/mx-redstone) | レッドストーン機構(電力伝播・トーチ・リピーター・ピストン) |
| [mx-ui](https://github.com/nerima-games/mx-ui) | HUD・メニュー・インベントリ・設定などの DOM サーフェス |
| [mx-multiplayer](https://github.com/nerima-games/mx-multiplayer) | ワイヤプロトコル・フレームコーデック・接続状態機械 |
| [mc-compose](https://github.com/nerima-games/mc-compose) | Layer 合成・フレームステージ全順序・セッションライフサイクル・modding entry point |
| [mc-dev-meta](https://github.com/nerima-games/mc-dev-meta) | 15 リポジトリを1つの pnpm workspace に束ねる開発用リポジトリ(非公開) |

## 開発体制

人間のメンテナー1人と AI コーディングエージェントによって開発されています。
共通の構成基準やレビューの進め方は、この `.github` リポジトリの各種標準文書にまとめています。
