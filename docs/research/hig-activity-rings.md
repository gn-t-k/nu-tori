# 輪の形で1日の食事を示してよいか

調査日: 2026-09-24
対象: `docs/ui-design/0001-first-release/` の ⑥ で決めた「1日の丸」（1本の輪を P・F・C の kcal で色分けし、一周で1日の目安にするもの）と、Apple のアクティビティリングとの関係

> **確認の方法と限界**
> - Apple Human Interface Guidelines（以下 HIG）の Activity rings のページは、HTML が JavaScript で組み立てられるため、同じ内容の JSON（`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/activity-rings.json`）を取得して**本文を直接読んだ**。出典にはふつうの URL を書く。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。
> - 本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。
> - 実機での確認はしていない。二次情報（ブログ、記事、SNS）は使っていない。

## 結論の要約

- アクティビティリングは、ムーブ・エクササイズ・スタンドにだけ使う。ほかのデータに使ったり、真似たり、作り変えたりしない（本文で確認）
- ほかの輪の形の要素は、アクティビティリングと見分けられるようにする。見分ける手段として、余白・線・ラベルを挙げ、色と大きさも助けになるとしている（本文で確認）。ほかの輪の形の要素を置くこと自体を禁じる文は、このページにない（本文からの読み取り）
- 1日の丸は、輪を1本にし、P・F・C の色を使い、ラベル（帯では曜日、日のまとめでは kcal と P・F・C）と余白で区切って、アクティビティリングと見分けられるようにする。形と色だけで十分に見分けられるかは、⑦で見た目を作るときに確かめる（本文からの読み取り）

## 根拠

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| アクティビティリングをほかのデータに使えるか | 使えない。「ムーブ・エクササイズ・スタンドの情報を示すためだけに使う」「ほかの目的のために真似たり作り変えたりしない。ほかの種類のデータを示すのに使わない」（"Use Activity rings only to show Move, Exercise, and Stand information." "Don't replicate or modify Activity rings for other purposes. Never use Activity rings to display other types of data."） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/activity-rings |
| ムーブなどの進み具合を別の輪で示せるか | 示せない。「ムーブ・エクササイズ・スタンドの進み具合を、ほかの輪の形の要素で示さない」（"Never show Move, Exercise, and Stand progress in another ring-like element."） | 本文で確認 | 同上 |
| アクティビティリング以外の輪を置けるか | 見分けられるようにすることを求めている。置くこと自体を禁じる文はない（本文からの読み取り）。「ほかの輪の形の要素は、アクティビティリングと見分けられるようにする」「余白、線、ラベルで分ける。色と大きさも分ける助けになる」（"Differentiate other ring-like elements from Activity rings." "use padding, lines, or labels to separate them from Activity rings. Color and scale can also help provide visual separation."） | 本文で確認（見分ける求め）、本文からの読み取り（置いてよいか） | 同上 |
| アクティビティリングの見た目の決まり | 色を変えない、いつも黒い背景に置く、などの決まりがある（"Never change the colors of the rings" "Always display Activity rings on a black background."） | 本文で確認 | 同上 |
| 1日の丸はどう見分けるか | HIG が挙げる余白・線・ラベルを使う。帯の丸には曜日のラベルを、日のまとめの大きな丸には kcal と P・F・C のラベルを添え、ほかの要素と余白と区切り線で分ける。輪の本数と色は補助として変える。アクティビティリングの輪の本数と色の値は、このページの文章からは確かめていない（色の値は画像で示されている）。ダークモードでは背景が黒くなるので、背景の違いには頼らない | 本文からの読み取り（上の3行から） | 同上 |

## 1日の丸への当てはめ

- 帯の小さな丸には曜日のラベルを添え、帯の区切り線と余白で区切る。日のまとめの大きな丸には kcal と P・F・C のラベルを添える
- 輪は1本にする
- 色は P・F・C の3色にし、アクティビティリングの色（ムーブ・エクササイズ・スタンド）に寄せない。色は⑦で決め、そのときに見分けられるかを確かめる
- nu-tori はアクティビティリングを表示しない（運動データを入れない決定のため）。そのため、同じ画面に並んで紛れることはない
