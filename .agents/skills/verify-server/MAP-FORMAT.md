# 地図の機能のファイルの形

`features/` の機能のファイルを足す・直すときの形。

1行目に見出し、続けてユーザーから見た振る舞いを1段落で書く。そのあとに次の4つの節をこの順で置く。

1. `Sub-features`: 短い ID と、1行の振る舞い
2. `How to get to it (user POV)`: ユーザーがたどり着く入口を全部。アプリの操作と、そのとき端末が呼ぶ API
3. `Driving it with verify-server`: `Preconditions:` で始め、操作ごとに、送るコマンドと、見えれば動いたと言える結果を対にする
4. `Gotchas`: 確かめを無駄にする、または無効にする罠

作りの説明は書かない。書くのは、ユーザーの経路、送る要求、要る状態、見える結果だけ。いまある機能だけを書き、予定の機能は書かない（`/pstack:maintain-verification-skill` が、アプリと食い違う地図をずれとして扱うため）。

## Issue の受け入れ条件から移すとき

実装の PR では、Issue の受け入れ条件（書き方は `docs/agents/issue-tracker.md` の「機能の受け入れ条件を地図の形で書く」）を、機能のファイルに移す。ID と振る舞いの行は `Sub-features` に、入口は `How to get to it (user POV)` に、前提は `Preconditions:` に、見える結果は `Driving it with verify-server` の項目に、文言を変えずに移す。

- 見える結果には、動かして確かめた送るコマンドを足す。`Gotchas` も、動かして見つけたものを書く
- 前提が、ほかの項目で作れる状態（「取り込んだ体重記録」は体重記録の「取り込む」で作れる）なら、`Preconditions:` に足さず、その項目のあとに並べる
