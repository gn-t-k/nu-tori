# エージェントが PostHog の数を読む道具を、ローカルとクラウドの両方で動かす

調査日: 2026-10-03
対象: エージェントが PostHog の数（出来事の件数、続き具合（retention）、ファネル、変えた前後の差）を読む道具を、ローカル（Mac の Claude Code・Codex・Cursor）とクラウド（Claude Code on the web。ネットは Full。Cursor の Cloud Agents）のどこでも動かす方法。目当ては、エージェントが「この変更で記録の続き具合が変わったか」を自分で確かめられること。前提は `docs/research/observability.md` の「PostHog」の節（2026-09-26。送る側の SDK・料金・置き場・消すこと）、`docs/research/sentry-agent-access.md`（2026-10-03。Sentry を読む道具。各ツールのクラウドの秘密の値とコネクタの扱い）、`docs/research/agent-tools-setup.md`。ここでは重ねず、読む側だけを書く

> **確認の方法と限界**
> - PostHog の公式の文書は posthog.com の Markdown 版（`<ページ>.md`）と `llms.txt` を読んだ（2026-10-03）。
> - PostHog の公式リポジトリ PostHog/posthog（64d0356、2026-10-02）を clone し、`cli/`（posthog-cli 0.18.9）、`services/mcp/`（ホストされた MCP と、CLI の `api` が使う道具の一覧）、`posthog/scopes.py` を読んだ。`posthog/api/user.py`、`posthog/api/query.py`、`frontend/src/lib/scopes.tsx` は同じコミットの raw を読んだ。npm の版と中身は registry.npmjs.org の JSON と tarball で確かめた。
> - claude.ai のコネクタの一覧に PostHog があるかは、Anthropic の MCP の登録簿の検索（この調査のセッションの道具）で確かめた。Claude Code on the web の秘密の値は code.claude.com/docs の `cloud-environments.md`、Cursor の Cloud Agents は cursor.com/docs の `cloud-agent/setup.md` を読み直した（2026-10-03）。macOS のキーチェーンは手元の `man security` を読んだ。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。ソースコードで確かめたものは「ソースで確認」と書き、ファイルを添える（次の版で変わりうるので、文書の約束より弱い）。本文やソースから推し量ったものは「本文からの読み取り」、探しても記述が無かったものは「本文を探したが記述なし」と書く。
> - **PostHog のアカウントでは何も動かしていない**（個人の API キーを作っていない、CLI も MCP も Query API も実際のプロジェクトに向けて呼んでいない）。Claude Code on the web と Cursor の Cloud Agents でも動かしていない。二次情報（ブログ、記事、SNS）は使っていない。
> - nu-tori の PostHog は EU にある（`ios/NuTori/Observability/ObservabilityKeys.swift` の `postHogHost` が `https://eu.i.posthog.com`、`server/src/observability/send-usage-events.ts` が `https://eu.i.posthog.com/batch/` に送り、消す API は `https://eu.posthog.com` を呼ぶ）。サーバーが送る出来事の `distinct_id` はアカウント ID（`send-usage-events.ts` の `distinct_id: accountId`）、iOS も `identify(accountId)` する。

## 追記（2026-10-09）: 確かめた結果

- 当てはめのとおり、`scripts/posthog-query` を置いた。鍵は preset「Performing analytics queries」（`query:read` だけ）、届く範囲は nu-tori のプロジェクトだけ。この鍵で、Mac から `HogQLQuery`（出来事ごとの件数）と `RetentionQuery`（週ごとの続き具合）が通った
- 当てはめの案から変えたこと
  - 鍵とプロジェクトの ID は、Cloudflare と同じく環境変数（`NU_TORI_POSTHOG_PROJECT_ID`、`NU_TORI_POSTHOG_READ_KEY`）だけで受け、Mac のキーチェーンは読まない。無ければ `Not authenticated` で止める（鍵を付けずに送る形はやめた）
  - 本文は文字列をつなげず node で組み、標準入力が JSON でないか `kind` が無ければ送らずに止める
- PostHog に送るのは本番だけ（サーバーは本番だけ、iOS はデバッグビルドで送らない）なので、「確かめていないこと」の、デバッグビルドが同じプロジェクトに送るかの問いは解けた
- 読む決まりは `docs/agents/tooling.md` の「PostHog を読む」

## 結論の要約

- **勧める形: Query API（`POST https://eu.posthog.com/api/projects/<project_id>/query/`）を curl で直接呼ぶ短い起動スクリプト `scripts/posthog-query` を1本置き、鍵は読むだけの個人の API キー（スコープ `query:read` の1つ、nu-tori のプロジェクトだけ）にする。MCP の設定には PostHog を置かない。** 理由:
  - 件数・続き具合・ファネル・前後の差は、`HogQLQuery`（SQL）、`RetentionQuery`、`FunnelsQuery`、`TrendsQuery` を同じ受け口に投げれば取れる（本文で確認）。スクリプトは JSON をそのまま渡すだけで、CLI の版を追わなくてよい
  - 要るのは `curl` と鍵だけで、5つの場所のどれでも同じ形で動く（本文からの読み取り）。Cursor の Cloud Agents はリポジトリの MCP の設定を読まないので、MCP をリポジトリに置いても全部には効かない（`sentry-agent-access.md` と同じ）
  - スコープを `query:read` だけにできるのは Query API を直接呼ぶ道だけ。公式の CLI の `api`（MCP の道具の一覧を呼ぶ）と MCP は、少なくとも `user:read` も要り（ソースで確認）、文書は広い「MCP Server」の preset（全部の `:write`）を勧める（本文で確認）
  - CLI は使うたびに PostHog（US）へ自分の使われ方を送り、止める設定がソースに見当たらない（ソースで確認／本文を探したが記述なし）。curl なら何も余計に送らない
- **比べたもの**:
  - **公式の MCP（`https://mcp.posthog.com/mcp`、リモート、無料）**: OAuth が既定、個人の API キーを `Authorization: Bearer` で渡すこともできる。`?readonly=true`（か `x-posthog-read-only`）で読む道具だけにでき、`x-posthog-project-id` でプロジェクトを固定できる（本文で確認）。claude.ai のコネクタの一覧にも「PostHog」（同じ URL）がある（観察）。各自の設定に足すのは任意でよいが、リポジトリには置かない
  - **公式の CLI（`posthog-cli`、0.18.9、Rust。npm の `@posthog/cli` は入れるときに実行ファイルを落とす）**: `posthog-cli exp query run '<HogQL>'` は `query:read` だけで動く（README で確認）が `exp` は「Experimental」で HogQL しか投げない（ソースで確認）。`posthog-cli api call query-retention ...` は Node が要り、MCP と同じ道具を広いスコープで呼ぶ。dSYM・ソースマップを上げる道具が主
  - **Query API を直接**: 上のとおり勧める
- **最小のスコープ**: `query:read` だけ（UI の preset「Performing analytics queries」が `['query:read']`。ソースで確認）。キーの「Access scope」で nu-tori のプロジェクトだけにする（本文で確認）。サーバーの Worker が人を消すのに使う `POSTHOG_PERSONAL_API_KEY`（`person:write`）は使い回さない
- **EU の URL**: 読む API は `https://eu.posthog.com`（取り込みの `eu.i.posthog.com` ではない）（本文で確認）。CLI は既定が US なので `POSTHOG_CLI_HOST=https://eu.posthog.com` が要る（本文で確認）
- **料金と上限**: Query API はいまは無料だが、PostHog は「いずれ課金する」と書く（"We strongly discourage Query API usage and will eventually charge for it"）（本文で確認）。プロジェクトごとに 1 時間 2,400 回・1 分 240 回・同時 3 本・実行 10 秒まで、ほかに個人の API キーには 1 時間の読む量（bytes）の予算があり、使い切ると `429`（`api_queries_budget_exceeded`）。予算の量は書かれておらず、有料のプランで大きくなる（本文で確認）。MCP への接続と道具の呼び出しは無料（本文で確認）
- **秘密の値**: Mac は macOS のキーチェーン（`security`）か各自のシェルの環境変数、Claude Code on the web は個人の環境の環境変数（Pro・Max なら API credentials も）、Cursor の Cloud Agents は Secrets（本文で確認、各社の文書）
- **公開の Issue・PR に貼ってはいけないもの**: `distinct_id`（nu-tori ではアカウント ID そのもの）、`person_id`・`$session_id`・`$device_id`・`$anon_distinct_id` などの ID、人の属性、出来事の行そのもの、人の一覧（`*-actors` の道具）。貼るのは集計（件数・率・差・中央値の秒）と、版・OS・日付の区切りまで（本文からの読み取り）。`query:read` は `persons` の表も読める（本文で確認）ので、スコープでは防げない

## 前提: 2026-10-03 時点の版

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 公式の CLI | `posthog-cli` 0.18.9（2026-09-28）。PostHog/posthog の `cli/`。npm の `@posthog/cli` 0.18.9 は `postinstall` で `releases.posthog.com`（だめなら GitHub Releases）から実行ファイルを落とす。Linux は glibc 2.35 以上。ほかに install script、Homebrew、Cargo | 本文で確認（README.md、CHANGELOG.md、npm の `package.json`） | https://github.com/PostHog/posthog/tree/master/cli 、https://registry.npmjs.org/@posthog/cli |
| 公式の MCP | ホストされたものだけを案内する（"a free, hosted endpoint"）。URL は `https://mcp.posthog.com/mcp`（streamable HTTP）。ソースは PostHog/posthog の `services/mcp` | 本文で確認 | https://posthog.com/docs/model-context-protocol.md |
| npm の `@posthog/mcp` | 名前が紛らわしいが、MCP サーバーの使われ方を PostHog に送る SDK（"PostHog SDK for Model Context Protocol (MCP) servers — tracks tool usage"）。読む道具ではない | 本文で確認 | https://registry.npmjs.org/@posthog/mcp |
| Query API | `POST /api/projects/:project_id/query/`。個人の API キーに Query Read の権限 | 本文で確認 | https://posthog.com/docs/api/queries.md |

## 問い1: 公式の MCP（`mcp.posthog.com`）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 認証 | OAuth が勧める道（"OAuth is the recommended path"）。クライアントが OAuth を使えないなら、「MCP Server」の preset で作った個人の API キーを `Authorization: Bearer` で渡す | 本文で確認 | https://posthog.com/docs/model-context-protocol/faq.md |
| EU | 文書は「認証のサーバーがログインしたアカウントで US か EU に自動で振り分ける」と書く。リポジトリの README は「EU の利用者は OAuth を EU に向けるため `mcp-eu.posthog.com` を使う」と書き、食い違う。API キーで来たときは、前段の Cloudflare Worker が US と EU の両方の `/api/users/@me/` を並べて呼び、通った方に送る（EU のキーも US に一度届く） | 前半は本文で確認、README も本文で確認、振り分けはソースで確認（services/mcp/src/proxy.ts） | 同上、services/mcp/README.md |
| 読むだけに絞る | `x-posthog-read-only: true` か `?readonly=true` で、作る・直す・消す道具を一覧から外す | 本文で確認 | faq.md（Restricting to read-only MCP tools） |
| プロジェクトの固定 | `x-posthog-project-id`（か `?project_id=`）。固定すると `switch-project` などが外れる | 本文で確認 | faq.md |
| 数を読む道具 | `execute-sql`、`query-trends`、`query-funnel`、`query-retention` はどれも `query:read` で読むだけ（`readOnlyHint: true`）。`query-trends-actors`・`query-retention-actors` などは人の一覧を返し、`person:read` も要る | ソースで確認（services/mcp/schema/tool-definitions-all.json） | 道具の一覧 https://posthog.com/docs/model-context-protocol/tools.md |
| 道具の数 | 数百あり、Claude Code・Codex などでは既定で `exec` の1つにまとめる「CLI mode」、Cursor では1つずつ並べる「tools mode」になる | 本文で確認 | faq.md（Choosing a tool mode） |
| 上限と料金 | 接続と呼び出しは無料。上限は API と同じで、MCP だけの上限は無い。LLM を中で使う道具は PostHog AI の支出として課金されうるが、組織の設定で AI のデータ処理を有効にしたときだけ出る | 本文で確認 | faq.md |
| データの扱い | MCP は PostHog への中継で、分析のデータを保存しない。セッションの状態（今の組織・プロジェクト）は API キーのハッシュで一時的に持つ | 本文で確認 | faq.md、services/mcp/README.md |
| MCP 自身の観測 | 道具の呼び出しの出来事は、エラーの旗などだけで値を持たない（CLI の側のコメント: "Mirrors the hosted server, whose tool-call events carry only the error flag"） | ソースで確認（services/mcp/src/cli/tool-call-properties.ts のコメント） | 同上 |
| claude.ai のコネクタ | ある。名前「PostHog」、説明「Query, analyze, and manage your PostHog insights」、URL `https://mcp.posthog.com/mcp` | 観察（MCP の登録簿の検索） | — |

各ツールでどう通すか（クラウドのセッションへの届き方、`.mcp.json` に同じ URL を書くとコネクタが隠れること、Cursor の Cloud Agents はダッシュボードで足して利用者ごとに OAuth、リポジトリの `.cursor/mcp.json` は読まないこと）は `sentry-agent-access.md` の問い1・問い3と同じなので繰り返さない。PostHog に固有の点:

- claude.ai のコネクタの URL には `?readonly=true` を付けられない（登録簿の URL は固定）。コネクタで読むだけにできるかは、OAuth の同意の画面で選べるスコープしだいで、文書に書かれていない（本文を探したが記述なし、faq.md）
- 自分の設定に足すなら `https://mcp.posthog.com/mcp?readonly=true&features=sql,insights` のように、読むだけと道具の分類で絞れる（本文で確認、faq.md の Filtering available MCP tools）

## 問い2: 公式の CLI（`posthog-cli`）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 何か | "Use PostHog from your terminal, your coding agents, local scripts, and CI/CD pipelines"。`api`（MCP の道具の一覧をシェルから呼ぶ）、`sourcemap`・`dsym`（記号の上げ）、`exp`（試験中） | 本文で確認 | https://posthog.com/docs/cli.md 、cli/README.md |
| CLI か MCP か | PostHog 自身が、シェルがあるなら CLI のほうが組み合わせやすく、大きなデータを文脈に入れる前に絞れて token が少なくて済むと書く。MCP はシェルの無いクライアント向け | 本文で確認 | cli.md（When to use the CLI） |
| 認証 | `posthog-cli login` はブラウザでデバイスコードの OAuth をし、個人の API キーを `~/.posthog/credentials.json` に保存する。ログインは「agent-cli」の用途を頼み、`posthog-cli api` の全部のスコープを渡す（"grants the full MCP / `posthog-cli api` scope set"）。端末（TTY）が無いと止まる | 本文で確認（cli.md）、保存先・用途・TTY はソースで確認（cli/src/login.rs、cli/src/utils/auth.rs） | 同上 |
| 環境変数 | `POSTHOG_CLI_HOST`（既定 `https://us.posthog.com`、EU は `https://eu.posthog.com`）、`POSTHOG_CLI_PROJECT_ID`、`POSTHOG_CLI_API_KEY`。優先は「引数 → 環境変数 → `--dotenv-file` → `~/.posthog/credentials.json`」。`api` は `POSTHOG_HOST`・`POSTHOG_PROJECT_ID`・`POSTHOG_API_KEY` も読む | 本文で確認 | cli.md、cli/README.md |
| HogQL を投げる | `posthog-cli exp query run '<HogQL>'` が結果を JSON Lines で出す。`--debug` で応答の全体。要るスコープは `query:read`。`HogQLQuery` しか投げず、`refresh: blocking` 固定 | スコープは本文で確認（README の表）、ほかはソースで確認（cli/src/experimental/query/command.rs、mod.rs） | cli/README.md |
| `exp` の位置づけ | "Experimental commands, not quite ready for prime time" | 本文で確認（`--help` の出力、README） | 同上 |
| `api` | `posthog-cli api call --json query-retention '{...}'` のように MCP の道具を呼ぶ。中身は同梱の Node のスクリプト（`posthog-api-cli.mjs`）で、Node が PATH に要る。文書は「MCP Server」の preset のキーを勧める | 本文で確認（cli.md、README）、Node はソースで確認（cli/src/api_proxy.rs） | 同上 |
| `api` に要るスコープ | 道具ごとのスコープ（`execute-sql` なら `query:read`）に加えて、利用者を引く `/api/users/@me/` を呼ぶ。この受け口は `user:read` を求める | ソースで確認（services/mcp/src/lib/StateManager.ts、posthog/api/user.py の `scope_object = "user"`）。`user:read` が無いと道具の呼び出しまで失敗するかは確かめていない | — |
| CLI 自身のテレメトリ | Rust の CLI は、コマンドの名前・版・OS・CI か・プロジェクトの ID と、落ちたときの例外を `posthog-rs` で PostHog に送る。`api` の Node のスクリプトは道具の名前・所要時間・失敗の分類を `https://us.i.posthog.com` に送る（値は送らない設計）。止める環境変数は見当たらない（`DO_NOT_TRACK` なども無い） | ソースで確認（cli/src/invocation_context.rs、cli/src/api_proxy.rs、services/mcp/src/cli/context.ts）、止め方は本文を探したが記述なし（cli.md、README） | 同上 |
| skill と AGENTS.md | `posthog-cli api agents-md install` が `AGENTS.md` に案内の一文を足し、`posthog-cli api skill install <id>` が `.agents/skills/` に skill を置く | 本文で確認 | cli.md（Setup for agents、Skills） |

nu-tori で CLI を使うなら、`agents-md install` と wizard（`npx @posthog/wizard cli add`）は使わない（`AGENTS.md` を書き換え、版を `@latest` で入れる）。版を固定して起動スクリプトから呼ぶ形になる（本文からの読み取り）。

## 問い3: Query API を直接呼ぶ

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 受け口 | `POST <host>/api/projects/:project_id/query/`、本文は `{"query": {"kind": ..., ...}, "name": "..."}`。`name` は `query_log` の表に残り、あとで調べやすい | 本文で確認 | https://posthog.com/docs/api/queries.md |
| EU の host | 読む・書く API（private）は `https://eu.posthog.com`、取り込み（public）は `https://eu.i.posthog.com`（"On EU Cloud, these are `https://eu.i.posthog.com` for public endpoints and `https://eu.posthog.com` for private ones"） | 本文で確認 | https://posthog.com/docs/api.md |
| 認証 | `Authorization: Bearer <個人の API キー>`（`phx_`）。本文に `personal_api_key` を入れる形もある | 本文で確認 | https://posthog.com/docs/api/personal-api-keys.md |
| プロジェクトの ID | プロジェクトの URL の数字（`https://eu.posthog.com/project/12345` の `12345`）。プロジェクトの設定にもある | 本文で確認 | cli.md、queries.md |
| 投げられる種類 | `HogQLQuery`（SQL）、`EventsQuery`、`TrendsQuery`、`FunnelsQuery`、`RetentionQuery`、`PathsQuery`。ファネルと継続率は SQL で書き直しにくいので専用の種類を使うよう書く | 本文で確認 | queries.md（Query types） |
| ファネルの応答 | 手順ごとの `count`、前の手順からの `average_conversion_time`・`median_conversion_time`（秒）。`people` は常に空。率は応答に無く、`count` から自分で割る | 本文で確認 | queries.md（Funnel response） |
| 継続率の応答 | 始まりの区切りごとに `values[n].count`（`values[0]` が始まりの人数）。率は自分で割る。`retentionType`（`retention_recurring`・`retention_first_time`・`retention_first_ever_occurrence`）、`period`（`Day`・`Week` など）、`totalIntervals` | 本文で確認 | queries.md（Retention queries） |
| 行の上限 | 既定 100 行、`LIMIT` を書けば 1 回 5 万行まで。`OFFSET` は個人の API キーでは `400`。書き出しの手段ではない | 本文で確認 | queries.md |
| キャッシュと非同期 | 既定でキャッシュする（`is_cached`）。`refresh` で `blocking`（既定）・`force_blocking`・`async` などを選ぶ。非同期は `GET .../query/:query_id/` で待つ | 本文で確認 | queries.md |
| スコープ | Query の受け口は、作る（POST）も含めてすべて読む扱いで `query:read`。一部の種類（MCP の分析など）は別のスコープを足す | ソースで確認（posthog/api/query.py の `scope_object_read_actions`、`_QUERY_KIND_SCOPES`） | — |
| `persons` も読めるか | 読める。文書の例が、同じ Query Read のキーで `persons` の `email` を取る | 本文で確認 | queries.md |

例（7日ごとの記録の続き具合を、ある版の前後で比べる。`<project_id>` は置き換える。出来事の名前は `server/src/observability/send-usage-events.ts` の `meal_received`）:

```bash
curl -fsS -H "Authorization: Bearer $NU_TORI_POSTHOG_READ_KEY" -H 'Content-Type: application/json' \
  https://eu.posthog.com/api/projects/<project_id>/query/ \
  -d '{"name":"agent: weekly meal retention",
       "query":{"kind":"RetentionQuery","dateRange":{"date_from":"-8w"},
                "retentionFilter":{"targetEntity":{"id":"meal_received","type":"events"},
                                   "returningEntity":{"id":"meal_received","type":"events"},
                                   "retentionType":"retention_first_time","period":"Week","totalIntervals":5}}}'
```

SQL で前後の差を出す例（人の ID は数えるだけで出さない）:

```sql
SELECT toStartOfWeek(timestamp) AS week, count() AS meals, count(DISTINCT person_id) AS people
FROM events
WHERE event = 'meal_received' AND timestamp >= now() - INTERVAL 8 WEEK
GROUP BY week ORDER BY week
```

## 問い4: 個人の API キーのスコープと置き方

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 作り方 | アカウントの設定の Personal API keys（EU は `https://eu.posthog.com/settings/user-api-keys`）で作る。スコープを選び、値は作った直後にしか見えない。1人 10 本まで。スコープはあとで変えられる（"You can always modify the scopes later"） | 本文で確認 | personal-api-keys.md |
| スコープの名前 | `<対象>:read` か `<対象>:write`。Query は `query` で、`write` は無い（UI で `disabledActions: ['write']`）。`posthog/scopes.py` の注に "Covers query and events endpoints" | ソースで確認（posthog/scopes.py、frontend/src/lib/scopes.tsx） | — |
| preset | 「Performing analytics queries」は `['query:read']` だけ。「Read-only access」は特権のスコープを除く全部の `:read`。「MCP Server」は特権を除く全部の `:write`、「Agent CLI」は CLI の `api` の分 | ソースで確認（frontend/src/lib/scopes.tsx の `API_KEY_SCOPE_PRESETS`） | — |
| 届く範囲 | キーごとに「組織全体」「特定のプロジェクト」「全部のプロジェクト（未指定）」がある | 本文で確認 | personal-api-keys.md（Viewing keys with organization access の Access scope） |
| 漏れたとき | GitHub の秘密の値の検出と組んでいて、公開のリポジトリで `phx_` が見つかると自動で回し、メールで知らせる | 本文で確認 | api.md（GitHub secret scanning） |
| 上限は誰の分か | 上限は組織のチーム全体で共有する（"These limits apply to **the entire team**"）。Query の受け口の上限は、ほかの受け口（人を消すなどの CRUD）とは別に数える | 本文で確認 | api.md（Rate limiting） |

## 問い5: 料金と上限

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Query API の料金 | 文書に料金の行は無い。「Endpoints vs Query API」のページが "We strongly discourage Query API usage and will eventually charge for it" と書く。ad hoc の探索的な問い合わせには Query API を勧め、本番の仕組みには Endpoints を勧める | 本文で確認（料金表に Query API の行が無いことは pricing.md を探して確認） | https://posthog.com/docs/endpoints/endpoints-vs-query-api.md 、https://posthog.com/pricing.md |
| 回数の上限 | プロジェクトごとに 1 時間 2,400 回、1 分 240 回、同時 3 本、1 本 60 スレッド、実行 10 秒。同時の枠が埋まると最大 30 秒待つ。古い上限（1 時間 120 回）のままの顧客もいる | 本文で確認 | queries.md（Rate limits） |
| 読む量の予算 | 個人の API キーの問い合わせは、プロジェクトごとの 1 時間の読む量（bytes）の予算から引く。使い切ると `429`（`api_queries_budget_exceeded`、`Retry-After`）。応答のヘッダー `X-PostHog-Query-Bytes-Read`・`X-PostHog-Query-Budget-Remaining-Bytes` で残りが分かる。キャッシュの結果は使い切っても返る。アプリの画面からの問い合わせには効かない。予算を大きくするには有料のプラン（基本料 $0 の従量課金でよい） | 本文で確認。無料のプランの予算の量は本文を探したが記述なし | queries.md（Hourly read budget） |
| 無料のプランで読めるか | 読める。無料と有料の違いは予算の大きさとして書かれている | 本文からの読み取り（queries.md） | 同上 |
| MCP | 接続と呼び出しは無料。下の問い合わせの分は通常の課金と上限に従う | 本文で確認 | faq.md |

nu-tori の量（利用者が少ない、出来事は月 100 万件の無料枠の内）では、8 週ほどの期間で絞った集計の問い合わせが予算に当たる見込みは小さい（本文からの読み取り。予算の量が書かれていないので確かめられない）。エージェントが何度も回すときは、応答のヘッダーで残りを見る。

## 場所ごとの表: どこに鍵を置き、どこへ出られるか

| 場所 | 鍵を置く場所 | `eu.posthog.com` へ出られるか | 確かさ | 出典 |
|---|---|---|---|---|
| Mac（Claude Code・Codex・Cursor） | macOS のキーチェーン（`security add-generic-password -a "$USER" -s nu-tori-posthog-read -w`。`-w` を最後に置くと値を尋ねるので、シェルの履歴に残らない）。読むのは `security find-generic-password -s nu-tori-posthog-read -w`。または各自のシェルの環境変数 | 出られる | `security` は本文で確認（`man security`）。履歴に残らないのは本文からの読み取り | `man security` |
| Claude Code on the web: 環境変数 | 個人の環境の Environment variables（`.env` の形）。「環境を使う人は誰でも値を読める」 | Full なら出られる（"Any domain"） | 本文で確認 | https://code.claude.com/docs/en/cloud-environments.md |
| Claude Code on the web: API credentials | Pro・Max だけ。Allowed websites に `eu.posthog.com`、ヘッダーは `Authorization`・`Bearer`。キーは VM にもコマンドにも入らず、Anthropic の agent proxy が付ける | 登録したホストは出られる | 本文で確認 | 同上（Add API credentials） |
| Cursor の Cloud Agents | ダッシュボードの Cloud Agents > Secrets。環境変数としてエージェントに渡る。環境ごとの Secrets もある | 既定で全部に出られる（`sentry-agent-access.md`） | 本文で確認 | https://cursor.com/docs/cloud-agent/setup.md |

API credentials で curl を使うなら、スクリプトは鍵が無いときに `Authorization` を付けずに送り、proxy に付けさせる形にできる（本文からの読み取り。動かしては確かめていない）。CLI は鍵が `phx_` で始まるかを送る前に確かめる（ソースで確認、cli/src/utils/auth.rs の `token_validator`）ので、API credentials だけでは動かない。

### 候補ごとに、5つの場所で動くか

```
                         Mac: Claude  Mac: Codex  Mac: Cursor  Claude web(Full)  Cursor Cloud
Query API を curl（勧める）  ○           ○           ○            ○                ○
posthog-cli exp query       ○           ○           ○            ○※1              ○※1
posthog-cli api             ○※2         ○※2         ○※2          ○※1※2            ○※1※2
リモート MCP（OAuth）        ○           ○           ○            ○※3              ○※4
```

- ※1 npm の `postinstall` が `releases.posthog.com` か GitHub から実行ファイルを落とす。Linux は glibc 2.35 以上（本文で確認、npm の `package.json`）。各クラウドの image の glibc は確かめていない
- ※2 Node が要り、スコープは少なくとも `user:read` と道具ごとのもの。文書は「MCP Server」の preset を勧める
- ※3 claude.ai のコネクタとして。`?readonly=true` は付けられない
- ※4 Cloud Agents のダッシュボードで足し、利用者ごとに OAuth

## 返る中身のうち、公開の場に貼ってはいけないもの

| 中身 | nu-tori での意味 | 貼ってよいか | 確かさ |
|---|---|---|---|
| `distinct_id` | アカウント ID（サーバーは `distinct_id: accountId`、iOS は `identify(accountId)`） | 貼らない | ソースで確認（nu-tori の `send-usage-events.ts`、`PostHogAnalyticsSession.swift`） |
| `person_id`、人の UUID | PostHog の人の ID。消す API の引数にもなる | 貼らない | 本文で確認（`observability.md` の「消すこと」） |
| `$session_id`、`$device_id`、`$anon_distinct_id` | 端末やセッションを結びつける ID | 貼らない | 本文からの読み取り |
| 人の属性（`persons.properties`） | iOS SDK が既定で版・OS・端末の種類を人の属性に入れる | 1人の分は貼らない | 本文で確認（`observability.md` の iOS SDK の節） |
| 出来事の行（`EventsQuery`、`SELECT *`） | 1件ごとに上の ID と時刻を持つ | 貼らない | 本文からの読み取り |
| `*-actors` の道具、`people` | 人の一覧 | 貼らない（Query API のファネルの `people` は常に空） | 本文で確認（queries.md） |
| 集計（件数、率、差、中央値の秒、版・週ごとの内訳） | ルートの `AGENTS.md` が PostHog に送ってよいとする「数・率・差・所要時間・旗」の集計 | 貼ってよい。ただし内訳の1つが 1〜2 人だと開発者自身や特定の人と分かりうるので、小さい数は「数人」とまとめる | 本文からの読み取り |
| プロジェクトの ID、組織の ID | 鍵ではない（鍵が無ければ何もできない）が、`server/wrangler.jsonc` では秘密の値の側に置いている | どちらでもよいが、今のリポジトリの扱いに合わせるなら貼らない | 本文からの読み取り |

nu-tori は記録の中身を PostHog に送らない決まり（ルートの `AGENTS.md`）なので、返る中身に体重や料理の名前は入っていないはずで、守るのは上の ID と1人ごとの行になる（本文からの読み取り）。読んだ結果はエージェントの会話（各社のサーバー）に入る点は Sentry と同じ。

## nu-tori への当てはめ

ここは、上の表からの読み取り。決めるのは開発者で、決めたことはストック（`docs/agents/tooling.md` など）に書く。

### 勧める形

```
エージェント ──Bash──> scripts/posthog-query ──curl──> https://eu.posthog.com/api/projects/<id>/query/
                         │
                         ├─ host（EU）とプロジェクトの ID をここ1か所に書く
                         └─ 鍵: NU_TORI_POSTHOG_READ_KEY があれば使う
                                無ければ Mac のキーチェーン（nu-tori-posthog-read）を読む
（任意）各自の設定にだけ、PostHog のリモート MCP（`?readonly=true`）。リポジトリの MCP の設定には置かない
```

### 置くファイル

`scripts/posthog-query`（実行できるようにする。`<project_id>` は秘密ではないが、上の表のとおり今の扱いに合わせて環境変数にしてもよい）:

```bash
#!/usr/bin/env bash
# エージェントと人が PostHog の数（件数・続き具合・ファネル・前後の差）を読む。Query API を直接呼び、置き場と鍵の受け取り方をここ1か所に置く
# 使い方: scripts/posthog-query < query.json   （query.json は {"kind":"RetentionQuery", ...} などの query の中身）
set -euo pipefail

# 読む API は取り込み（eu.i.posthog.com）と別の host
host="https://eu.posthog.com"
project_id="${NU_TORI_POSTHOG_PROJECT_ID:-<project_id>}"

# 読むだけ（query:read）の鍵を、Worker の人を消す鍵（POSTHOG_PERSONAL_API_KEY）と混ざらない名前で受け取る
key="${NU_TORI_POSTHOG_READ_KEY:-}"
if [ -z "$key" ] && command -v security >/dev/null 2>&1; then
    key="$(security find-generic-password -s nu-tori-posthog-read -w 2>/dev/null || true)"
fi

auth=()
if [ -n "$key" ]; then
    auth=(-H "Authorization: Bearer $key")
fi
# 鍵が無いときは付けずに送る（Claude Code on the web の API credentials なら proxy が付ける）

query="$(cat)"
curl -sS --fail-with-body ${auth[@]+"${auth[@]}"} -H 'Content-Type: application/json' \
    "$host/api/projects/$project_id/query/" \
    --data-binary "{\"name\":\"agent\",\"query\":$query}"
```

- 版を固定するものが無い（curl だけ）。macOS の bash 3.2 は `set -u` で空の配列を `"${auth[@]}"` と展開すると unbound variable で止まるので、`${auth[@]+"${auth[@]}"}` と書いた。`--fail-with-body` は curl 7.76 以上が要る。どちらも実際に走らせては確かめていない
- ルートの `AGENTS.md`（または `docs/agents/tooling.md`）に足す一文の例:

```
- PostHog の数（出来事の件数、続き具合、ファネル、変えた前後の差）は `scripts/posthog-query` で読む（標準入力に Query API の query を JSON で渡す。継続率は RetentionQuery、ファネルは FunnelsQuery、ほかは HogQLQuery）。期間は8週ほどに絞り、人の一覧や出来事の行は取らない。公開の Issue・PR・コメントに貼るのは集計（件数・率・差・中央値の秒、版・週ごとの内訳）までで、distinct_id・person_id などの ID と1人ごとの行は貼らない。1〜2人の内訳は「数人」とまとめる
```

- `.mcp.json`・`.codex/config.toml`・`.cursor/mcp.json` には何も足さない
- `posthog-cli api agents-md install` と wizard は使わない（`AGENTS.md` を書き換え、版を `@latest` で入れる）

### 開発者が手でやること

1. **鍵を作る**: `https://eu.posthog.com/settings/user-api-keys` で、preset「Performing analytics queries」（スコープ `query:read` だけ）を選び、届く範囲を nu-tori のプロジェクトだけにする。値は作った直後にしか見えない。Worker の `POSTHOG_PERSONAL_API_KEY`（人を消す、`person:write`）とは別のキーにする
2. **プロジェクトの ID を決める**: プロジェクトの URL の数字を、スクリプトに書くか環境変数 `NU_TORI_POSTHOG_PROJECT_ID` に置くかを決める
3. **Mac**: `security add-generic-password -a "$USER" -s nu-tori-posthog-read -w` を一度走らせ、尋ねられたら鍵を貼る
4. **Claude Code on the web**: 個人の環境（共有しない）の Environment variables に `NU_TORI_POSTHOG_READ_KEY=<鍵>`。ネットは Full のままでよい。Pro・Max なら、代わりに API credentials（Allowed websites `eu.posthog.com`、`Authorization`・`Bearer`）にすると鍵が VM に入らない
5. **Cursor の Cloud Agents**: ダッシュボードの Cloud Agents > Secrets に `NU_TORI_POSTHOG_READ_KEY`
6. 最初に各場所で `echo '{"kind":"HogQLQuery","query":"SELECT count() FROM events WHERE timestamp >= now() - INTERVAL 7 DAY"}' | scripts/posthog-query` を一度走らせ、動いたかを `docs/agents/tooling.md` に書く

### 最小の権限

- 個人の API キー1本、スコープ `query:read` だけ、届く範囲は nu-tori のプロジェクトだけ
- `query:read` でも `persons` の表と出来事の行は読める。ID を外に出さないのは、スコープでなく `AGENTS.md` の一文で守る
- MCP を各自で足すなら `?readonly=true` を付け、API キーで渡すなら `x-posthog-project-id` で固定する

### 確かめていないこと

- 実際の PostHog のプロジェクトに向けては、どの道具も動かしていない
- 無料のプランの「1 時間の読む量の予算」がどれだけか（文書に数が無い）
- Claude Code on the web の API credentials だけで、`Authorization` を付けない curl が通るか
- claude.ai のコネクタと Cursor の Cloud Agents の OAuth で、EU のアカウントに正しく向くか（文書は自動と書き、README は EU に `mcp-eu.posthog.com` を勧める）。OAuth の同意で読むだけのスコープに絞れるか
- `posthog-cli api` が `user:read` の無いキーで道具を呼べるか
- 各クラウドの image の glibc が CLI の要る 2.35 以上か
- iOS のデバッグビルドが本番と同じプロジェクトに送るか（`ObservabilityKeys.swift` のトークンは1つ）。送るなら、前後の差を見るときに版やビルドで分ける必要がある
- Query API がいつ有料になるか

## 出典一覧

PostHog（Markdown 版。2026-10-03）
- llms.txt: https://posthog.com/llms.txt
- MCP: https://posthog.com/docs/model-context-protocol.md 、FAQ: https://posthog.com/docs/model-context-protocol/faq.md 、道具の一覧: https://posthog.com/docs/model-context-protocol/tools.md 、Claude Code: https://posthog.com/docs/model-context-protocol/claude-code.md 、Cursor: https://posthog.com/docs/model-context-protocol/cursor.md
- CLI: https://posthog.com/docs/cli.md
- API overview（host、認証、上限、GitHub の秘密の値の検出）: https://posthog.com/docs/api.md
- API queries: https://posthog.com/docs/api/queries.md
- Personal API keys: https://posthog.com/docs/api/personal-api-keys.md
- Endpoints vs Query API: https://posthog.com/docs/endpoints/endpoints-vs-query-api.md
- Pricing: https://posthog.com/pricing.md

PostHog のソース（PostHog/posthog、64d0356、2026-10-02）: https://github.com/PostHog/posthog
- `cli/`（README.md、CHANGELOG.md、Cargo.toml、build.rs、src/login.rs、src/utils/auth.rs、src/invocation_context.rs、src/api_proxy.rs、src/commands.rs、src/api/client.rs、src/experimental/query/）
- `services/mcp/`（README.md、src/proxy.ts、src/index.ts、src/lib/StateManager.ts、src/cli/config.ts、src/cli/context.ts、src/cli/tool-call-properties.ts、schema/tool-definitions-all.json）
- `posthog/scopes.py`、`posthog/api/user.py`、`posthog/api/query.py`、`frontend/src/lib/scopes.tsx`
- npm: https://registry.npmjs.org/@posthog/cli （0.18.9 の tarball の `package.json`）、https://registry.npmjs.org/@posthog/mcp

Anthropic・Cursor・Apple（2026-10-03）
- Configure cloud environments: https://code.claude.com/docs/en/cloud-environments.md
- claude.ai のコネクタの一覧: MCP の登録簿の検索（観察）
- Cursor Cloud Agents setup: https://cursor.com/docs/cloud-agent/setup.md
- macOS `security(1)`: 手元の `man security`
