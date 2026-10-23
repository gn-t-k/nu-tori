---
name: steward
description: このリポジトリの PR を CI が通って merge できるまで見張るときの決まり。Claude Code on the web の PR の見張りが読む。
disable-model-invocation: true
---

# PR の見張り

## UI テストの結果

UI テストか画面の経路を変える PR は、CI が緑でも、`ios/AGENTS.md` の「確かめる」の UI テストの結果が PR の本文にそろうまで、merge できる状態に入らない。そろったとは、本文に書いた結果のコミットが PR の先頭のコミットと同じで、通っていること。

Mac の結果を頼むときは、開発者が Mac のセッションに貼るプロンプトを次の形で渡す。結果は PR のコメントで届くので、届いたらコミットと結果を本文に書き、添えられたスクリーンショットは本文の Evidence に貼る（`docs/agents/git.md`）。

```text
gn-t-k/nu-tori の #<PR> のコミット <SHA> で scripts/check ios-ui-test を回して、結果をその PR にコメントしてください。
全件で15分ほどかかるので、コマンドの時間の制限を延ばすか、裏で回す。
コメントには、コミットと、通ったか、落ちたらテストの名前と失敗の要約を書く。
<見た目が変わる PR なら次の1行を足す>
変えた画面（<画面と、それを写す UI テストのスクリーンショットの名前>）のスクリーンショットを xcresult から書き出し、gh の --attach でそのコメントに添える。
```
