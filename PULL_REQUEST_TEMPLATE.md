<!--
org 全体のデフォルト PR テンプレートです。該当しない項目は削除してください。
詳細なルールは以下を参照してください。
https://github.com/nerima-games/.github/blob/main/REVIEW_STANDARD.md
https://github.com/nerima-games/.github/blob/main/PACKAGE_STANDARD.md
-->

## この変更で何が変わるか

<!-- 1〜2文で。マージ後にどの挙動が変わるか。 -->

## なぜ

<!-- この変更が解決する問題。関連 issue があればリンク。 -->

## 確認

nerima-games は単独メンテナー + AI コーディングエージェントによる開発体制で、
自己レビュー・自己マージが通常の運用です(詳細は
[REVIEW_STANDARD.md](https://github.com/nerima-games/.github/blob/main/REVIEW_STANDARD.md))。
マージ前に以下を自分で確認してください。

- [ ] `pnpm verify` (typecheck + lint + test) がローカルで通る
- [ ] 変更に対応するテストがある、または既存テストの更新で十分と判断した理由がある
- [ ] 公開 API に影響する変更であれば `docs/` を更新した
- [ ] 他リポジトリを新たに import した場合、依存許可([DEPENDENCY_POLICY.md](https://github.com/nerima-games/.github/blob/main/DEPENDENCY_POLICY.md))を確認した
- [ ] 破壊的変更であれば、その旨とバージョニング方針([RELEASE_STANDARD.md](https://github.com/nerima-games/.github/blob/main/RELEASE_STANDARD.md))を明記した

## レビュアーへのメモ

<!--
差分だけでは伝わらないこと: 検討して別案を選ばなかった理由、意図的に対応しなかったケース、
別 PR で対応する予定のフォローアップなど。
-->
