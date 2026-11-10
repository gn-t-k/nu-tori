# 送った文章と返事

ユーザーが入力欄に書いて送ると、吹き出しの下に「読んでいます」が出て、返事が届くとそれに置き換わる。食事と読み分けられた文章には食事のカードがつながり、会話として送り直せる。返事を作れなかった文章には1行が出て、送り直せる。吹き出しと返事は長押しでコピー・選択できる。

## Sub-features

- `reply-send` 書いて送ると吹き出しが出て、読んでいますのあとに返事が届く
- `reply-meal-text` 食事の文章を送ると、吹き出しの下に食事のカードがつながり、推定が届くと料理の名前になる
- `reply-resend-as-conversation` 食事になった文章を会話として送り直すと、カードが消えて返事が届く
- `reply-resend` 返事を作れなかった文章を送り直すと、1行が消えて返事が届く
- `reply-copy-select` 吹き出しと返事を長押しして、コピー・テキストを選択できる

## How to get to it (user POV)

- 入力欄の書く欄（`composer-field`）に書くか、プリセットのチップ（`preset-chip`）を押して、送る（`composer-send`）を押す
- 食事のカードのつながった吹き出しの「会話として送り直す」（`resend-as-conversation`）を押す
- 「返事を作れませんでした」の1行（`reply-failed-line`）の「送り直す」（`reply-resend`）を押す
- 吹き出しか返事を長押しし、メニューの「コピー」か「テキストを選択」を押す

## Driving it with verify-ios

Preconditions:

- なし（場面が、送った文章の本文で答え方を決める偽の同期サーバーを作る）

- **送ると返事が届く・送り直す。** `$S/ui-test.sh SendTextWithConversationScenarioUITests`。プリセットを送ると `reply-reading` と吹き出しが出て、返事（「今日は朝ごはんから」）が届くと読んでいますが消える。「昼は親子丼」を送るとカードがつながって親子丼になり、会話として送り直すとカードが消えて返事（「親子丼の話」）が届く。「次の食事は？」は作れなかった1行になり、送り直すと返事（「野菜の多い定食」）が届く
- **ひらがなを確定して送る。** `$S/ui-test.sh SendConfirmedKanaTextUITests`。確定してから送ると、書く欄が空に戻る
- **コピーと選択。** `$S/ui-test.sh CopyAndSelectUtteranceUITests`。吹き出しをコピーすると書く欄に貼り付けられ、テキストを選択を選ぶとその場で全体が選ばれ、余白を押すと戻る
- **手で見るとき。** `$S/launch.sh "$run" signed-in conversation` で開き、`composer-field` に書いて `composer-send` を押す。返事は数回あとの取得で届く

## Gotchas

- 返事の本文と読み分けは偽の同期サーバーが本文で決めた値。サーバーの読み分けと返事は `verify-server` の [送った文章と返事](../../verify-server/features/reply.md) で確かめる
- 見守る要求で返事の本文が流れる様子は、偽の同期サーバーでは流れない（取りに行く要求で届く）
- かなを打つ UI テストは、`scripts/check ios-ui-test` がシミュレーターにかなのキーボードを入れてから回す。手で動かす端末には入っていないので、手では `type_text` で打つ
