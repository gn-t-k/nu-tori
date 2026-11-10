# 地図の機能のファイルの形

`features/` の機能のファイルを足す・直すときの形。サーバーの地図（`../verify-server/MAP-FORMAT.md`）と同じ形にそろえる。

見出しの1行と、ユーザーから見た振る舞いの1段落のあとに、次の4つの節をこの順で置く。

1. `Sub-features`: 短い ID と、1行の振る舞い
2. `How to get to it (user POV)`: ユーザーがたどり着く入口を全部。どの画面のどれを押すか
3. `Driving it with verify-ios`: `Preconditions:` で始め、入口ごとに、確かめ方と、見えれば動いたと言える結果を対にする
4. `Gotchas`: 確かめを無駄にする、または無効にする罠

作りの説明は書かない。書くのは、ユーザーの経路、操作、要る状態、見える結果だけ。いまある機能だけを書き、予定の機能は書かない（`/pstack:maintain-verification-skill` が、アプリと食い違う地図をずれとして扱うため）。

## 確かめ方の書き方

- UI テストのある入口は、手順を書き直さず、`$S/ui-test.sh <クラス>` と、そのテストのメソッドの名前を書く。見える結果は、そのテストが確かめる画面の要素を、ユーザーの言葉で1行にする（流れの正本は UI テストで、地図は入口と UI テストを結ぶ）
- UI テストの無い入口は、`$S/launch.sh "$run" <アカウント> <API の場面>` で開く場面と、MobileBuildMCP で押す要素（accessibility identifier か、画面に出る文字）と、操作のあとに見える要素と値を書く
- UI テストを足した・名前を変えたら、地図の行も直す

## Issue の受け入れ条件から移すとき

実装の PR では、Issue の受け入れ条件（書き方は `docs/agents/issue-tracker.md` の「機能の受け入れ条件を地図の形で書く」）を、機能のファイルに移す。ID と振る舞いの行は `Sub-features` に、入口は `How to get to it (user POV)` に、前提は `Preconditions:` に、見える結果は `Driving it with verify-ios` の項目に、文言を変えずに移す。

- 見える結果には、動かして確かめた確かめ方（UI テストのクラス、または開く場面と押す要素）を足す。`Gotchas` も、動かして見つけたものを書く
- 前提が、ほかの項目で作れる状態なら、`Preconditions:` に足さず、その項目のあとに並べる
