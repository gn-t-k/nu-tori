# nu-tori-ops をまたぐ作業

gn-t-k/nu-tori-ops（以下 ops）は非公開のリポジトリ。ops のことを公開の nu-tori（Issue の brief、PR の本文、コミット、文書）に書くときは、ops の `AGENTS.md` の「決まり」の節に従う。正本は ops にあり、ここには写さない。

## ops を読み書きする

1. `source_url` を `https://github.com/gn-t-k/nu-tori-ops` にしたセッションを `create_session` で立てる。名前は `#<nu-tori の Issue の番号> <ゴール>` にする（`/dispatch` の5節の形。`/dispatch` が Issue に結びつけられる）
2. プロンプトに、ops でしてほしいことと、そのために要る nu-tori の Issue の中身を書く。そのセッションのスコープは ops だけで、nu-tori の Issue も PR も読めない
3. 返事は `list_events`（`kinds: ["result"]`）で読む。ops の「決まり」の節を読むだけのときも、そのセッションに読ませて返させる

**Why:** 子のセッションが `add_repo` で ops を足そうとすると、人が頼んだのではないとして auto mode に拒まれ、開発者が頼むまで約18時間止まった。brief を書いたセッションも ops を読めず、ops の決まりと食い違う受け入れ条件を書いた（#911）。`source_url` を ops にしたセッションは、人の手を待たずに ops の clone・push・GitHub の MCP が通る（#931 で試した）。
