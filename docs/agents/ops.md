# nu-tori-ops をまたぐ作業

gn-t-k/nu-tori-ops（以下 ops）は非公開のリポジトリ。ops のことを公開の nu-tori（Issue の brief、PR の本文、コミット、文書）に書くときは、ops の `AGENTS.md` の「決まり」の節に従う。正本は ops にあり、ここには写さない。nu-tori のセッションからは ops を読めないので、その節も下の手順で ops のセッションに読ませて返させる。

## ops を読み書きする

1. `source_url` を `https://github.com/gn-t-k/nu-tori-ops` にしたセッションを `create_session` で立てる。名前は `#<nu-tori の Issue の番号> <ゴール>` にする（`/dispatch` の5節の形。`/dispatch` が Issue に結びつけられる）。`create_session` が無いセッション（Mac の上など）では、名前とプロンプトを組にして開発者に渡し、ops を source にしたセッションを立ててもらう
2. プロンプトに、ops でしてほしいことと、そのために要る nu-tori の Issue の中身を書く。そのセッションのスコープは ops だけで、nu-tori の Issue も PR も読めない
3. `get_session` の `status_bucket` が `WORKING` でなくなってから、`list_events`（`kinds: ["result"]`）の最後の1件を返事として読む。まだ `WORKING` なら、ほかの作業を進めてから読み直す。手順 1 で開発者に渡したときは、ops のセッションの返事を貼ってもらい、それを返事として読む

**Why:** 子のセッションが `add_repo` で ops を足そうとすると、人が頼んだのではないとして auto mode に拒まれ、開発者が頼むまで約18時間止まった。brief を書いたセッションも ops を読めず、ops の決まりと食い違う受け入れ条件を書いた（#911）。`source_url` を ops にしたセッションは、人の手を待たずに ops の clone・push・GitHub の MCP が通る（#931 で試した）。
