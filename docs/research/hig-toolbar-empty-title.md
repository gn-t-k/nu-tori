# 根の画面のナビゲーションバーに題を出さなくてよいか

調査日: 2026-09-24
対象: `docs/ui-design/0001-first-release/` の ⑥ で決めた、タイムラインのナビゲーションバー（題を空にし、右端にアカウント、すぐ下に1日の丸の帯）

> **確認の方法と限界**
> - Apple Human Interface Guidelines（以下 HIG）の Toolbars のページは、HTML が JavaScript で組み立てられるため、同じ内容の JSON（`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/toolbars.json`）を取得して**本文を直接読んだ**。出典にはふつうの URL を書く。iOS のナビゲーションバーの指針は、このページにまとめられている（"incorporated navigation bar guidance"）。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。
> - 本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。
> - 実機での確認はしていない。二次情報（ブログ、記事、SNS）は使っていない。

## 結論の要約

- iOS のナビゲーションバーは、ツールバーの一種として扱われる（本文で確認）
- 題が冗長なら、題の場所を空にしてよい。メモの例がある（本文で確認）
- 項目は、ナビゲーションバーの先頭・中央・末尾の3か所に置ける（本文で確認）
- タイムラインは標準のナビゲーションバーを使い、題を空にし、右端にアカウントを置けば、独自のバーを作らずに済む（本文からの読み取り）

## 根拠

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| ナビゲーションバーとは | 階層を移るための操作を持つツールバー。「iOS では、ナビゲーションのためのツールバーをナビゲーションバーと呼ぶことがある」（"In iOS, a navigation-specific toolbar is sometimes called a navigation bar."） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/toolbars |
| 題を空にしてよいか | よい。「題が冗長に思えるなら、題の場所を空にしてよい。たとえばメモは…今のメモに題を付けない」（"If titling a toolbar seems redundant, you can leave the title area empty. For example, Notes doesn't title the current note…"） | 本文で確認 | 同上 |
| 題にアプリ名を使ってよいか | 使わない（"Don't title windows with your app name."） | 本文で確認 | 同上 |
| 項目を置ける場所 | 先頭、中央、末尾の3か所（"You can position toolbar items in three locations: the leading edge, center area, and trailing edge of the toolbar."） | 本文で確認 | 同上 |
| タイムラインに当てはめると | 根はタイムラインの1つでタブもないので、題は「タイムライン」かアプリ名になり、どちらも位置を知る助けにならない。題を空にし、末尾にアカウントを置く | 本文からの読み取り（上の2行から） | 同上 |
