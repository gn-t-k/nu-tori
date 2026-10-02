# エージェントが Sentry のクラッシュを読む道具を、ローカルとクラウドの両方で動かす

調査日: 2026-10-03
対象: エージェントが Sentry の課題（issue）・イベント・スタックトレース・端末・版・件数を読む道具を、ローカル（Mac の Claude Code のデスクトップアプリと CLI、Codex の CLI とアプリ、Cursor）とクラウド（Claude Code on the web、Codex Cloud、Cursor の Cloud Agents）のどこでも動かす方法。前提は `docs/research/agent-tools-setup.md`（2026-09-26。各ツールが MCP の設定をどこから読むか）と `docs/research/xcode-cloud-dsym.md`（sentry-cli で dSYM を上げる）

> **確認の方法と限界**
> - Sentry の公式リポジトリを clone してソースと文書を読んだ: getsentry/sentry-mcp（GitHub で getsentry/toolkit に転送される。MCP と新しい `sentry` CLI が同じモノレポにある。6054887、2026-10-02）、getsentry/sentry-cli（a7298b0、3.8.0 の直後）。npm の版と公開者は registry.npmjs.org の JSON で確かめた。
> - Sentry の文書は docs.sentry.io の Markdown 版（`<ページ>.md`）と `llms.txt` を読んだ。Claude Code は code.claude.com/docs の Markdown 版、Codex は learn.chatgpt.com/docs の Markdown 版と `llms.txt`、Cursor は cursor.com/docs の Markdown 版を読んだ（いずれも 2026-10-03）。
> - claude.ai のコネクタの一覧に Sentry があるかは、Anthropic の MCP の登録簿の検索（この調査のセッションの道具）で確かめた。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。ソースコードで確かめたものは「ソースで確認」と書き、ファイルを添える（次の版で変わりうるので、文書の約束より弱い）。本文やソースから推し量ったものは「本文からの読み取り」、探しても記述が無かったものは「本文を探したが記述なし」と書く。
> - **Sentry のアカウントでは何も動かしていない**（トークンを作っていない、CLI も MCP も実際の組織に向けて呼んでいない）。Codex Cloud と Cursor の Cloud Agents でも動かしていない。二次情報（ブログ、記事、SNS）は使っていない。
> - nu-tori の Sentry の組織は EU（`de.sentry.io`）にある（`ios/NuTori/Observability/ObservabilityKeys.swift` の DSN が `ingest.de.sentry.io`。`docs/adr/0017-sentry-posthog-workers-logs.md` も EU と書く）。

## 結論の要約

- **勧める組み合わせ: Sentry の新しい公式 CLI（npm の `sentry`、版を固定）を起動スクリプト `scripts/sentry` から呼ぶのを共通の土台にし、Sentry の MCP はリポジトリの MCP の設定に置かない。** 7つの場所のすべてで動く見込みがあるのはこれだけ（本文からの読み取り。下の「場所ごとの表」）。理由:
  - **Codex Cloud には MCP を使う道が文書に無い**（本文を探したが記述なし）。Bash とネットがあれば動く CLI か curl しか、7つすべてをまたげない
  - `sentry issue view <ID> --json` が課題と最新のイベント（スタック、端末、版のタグ）を1回で返し、`sentry issue events <ID> --full` がイベントごとのスタックを返す（本文で確認、CLI の skill の文書）。EU の組織は API が返す `regionUrl` に自動で向き直す（ソースで確認）
  - トークンは環境変数 `SENTRY_AUTH_TOKEN` で渡せ、Mac では `sentry auth login --read-only` で読むだけの OAuth にでき、トークンの文字列を扱わずに済む（本文で確認）
  - 版・テレメトリの停止・組織の指定を `scripts/sentry` の1か所に書け、`docs/agents/tooling.md` の「起動スクリプトの1か所」の決まりにそのまま合う
- **足してよいもの（任意、各自の設定に置く）**: Sentry の公式のリモート MCP（`https://mcp.sentry.dev/mcp`、OAuth）は、ローカルの3つのツールと、Claude Code のクラウドのセッション（claude.ai のコネクタとして）、Cursor の Cloud Agents（ダッシュボードの HTTP の MCP、利用者ごとの OAuth）では動く（本文で確認）。ただし**リポジトリの `.mcp.json` に `mcp.sentry.dev` を書くと、同じ URL の claude.ai のコネクタが隠れる**（本文で確認）ので、リポジトリには書かない。
- **トークンの最小のスコープ**: 個人のトークン（Personal Token）で `org:read`、`project:read`、`team:read`、`event:read`、`member:read`。CLI の `--read-only` が求める5つと同じ（本文で確認）。課題とイベントを読む API は `event:read` で足りる（本文で確認）。MCP の読むだけの道具（inspect）は前の4つで足りる（ソースで確認）。`project:releases` も `org:ci` も書き込みも要らない。個人のトークンのスコープはあとから変えられない（本文で確認）。dSYM を上げる組織のトークン（`sntrys_`、Xcode Cloud の `SENTRY_AUTH_TOKEN`）は課題を読めないので使い回さない（本文からの読み取り）。
- **クラウドで秘密の値を置く場所**: Claude Code on the web は個人の環境の環境変数（Pro・Max なら API credentials も。ただし CLI と組み合わせて動くかは未確認）、Codex Cloud は Network secrets か Personal vault、Cursor の Cloud Agents は Secrets（環境変数として渡る）（本文で確認）。
- **ネット**: Claude Code on the web の既定（Trusted）にも、Codex Cloud の「Package managers」にも `sentry.io` は無い。Claude Code は Custom で `sentry.io` と `*.sentry.io` を、Codex は `sentry.io` と `de.sentry.io` を足す。Cursor の Cloud Agents は既定で全部に出られる（本文で確認）。
- **Sentry の stdio の MCP（`@sentry/mcp-server`）は勧めない**。動きはする（`SENTRY_ACCESS_TOKEN`、LLM の API キーは要らない）が、Codex Cloud で使えず、Cursor の Cloud Agents はリポジトリの `.cursor/mcp.json` を読まないので、3つの MCP の設定に置いても7つのうち4つ（ローカル3つと Claude Code のクラウド）にしか効かない（本文からの読み取り）。
- **sentry-cli（Rust、`sentry-cli`）は読む道具にならない**。課題の一覧（ID・題・最終発生・状態・レベル）とイベントの一覧（ID・日時・題）しか出さず、スタックは出さない（ソースで確認）。dSYM を上げる用途のまま残す。
- **前の調査で書き直す点**は末尾の「`agent-tools-setup.md` で書き直す点」。主なものは、Codex Cloud の文書が新しい「Cloud environments」に変わり、前に引いたページが「Legacy」になったこと、Codex Cloud でリポジトリのスキルを読むと書かれたこと、Claude Code on the web に API credentials が足されたこと。

## 前提: 2026-10-03 時点の版

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 新しい `sentry` CLI | npm の `sentry` の `latest` は 0.46.0（2026-10-01）。リポジトリは getsentry/toolkit の `packages/cli`、公開者は `zeeg`・`sentry-bot`、依存は無く、Node 20 以上（`engines: {"node": ">=20.0"}`）。ほぼ毎週〜隔週で上がっている（0.43.0 が 2026-08-21、0.45.0 が 09-10） | 本文で確認 | https://registry.npmjs.org/sentry 、https://github.com/getsentry/toolkit/tree/main/packages/cli |
| Sentry の MCP（stdio） | npm の `@sentry/mcp-server` の `latest` は 0.42.0（2026-09-25）。Node 22.13 以上。コマンド名は `sentry-mcp` | 本文で確認 | https://registry.npmjs.org/@sentry/mcp-server |
| Sentry の MCP（リモート） | `https://mcp.sentry.dev/mcp`（streamable HTTP）。MCP の登録簿の `server.json` に載る | 本文で確認 | getsentry/toolkit の `server.json` |
| sentry-cli（Rust） | 3.8.0。`scripts`・`ios/ci_scripts/ci_post_xcodebuild.sh` は 3.8.0 を使う | 本文で確認 | https://github.com/getsentry/sentry-cli |
| Claude Code | 2.1.288（2026-10-02） | 本文で確認 | https://code.claude.com/docs/en/changelog.md |

## 問い1: Sentry の公式のリモート MCP（`mcp.sentry.dev`、OAuth）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 認証のしかた | 既定は MCP の OAuth。ほかに、`Authorization: Sentry-Bearer <Sentry の API トークン>` を付けると OAuth を飛ばす（"`Sentry-Bearer` is intentionally separate from `Bearer`: `Bearer` is reserved for MCP OAuth access tokens"）。この形ではサーバーはトークンを保存も検証もせず、そのまま Sentry の API に渡す | 本文で確認 | getsentry/toolkit の README.md、docs/specs/sentry-bearer-cloudflare-auth.md |
| 道具のまとまり（skills） | `inspect`（読むだけ。課題・イベント・トレース・リリースなど。既定で有効）、`seer`（Sentry の AI。既定で有効）、`triage`、`project-management`（既定で無効）。`?skills=inspect` で絞れる | ソースで確認（packages/mcp-core/src/skills.ts）、絞り方は本文で確認 | 同上 |
| スタックを読む道具 | `get_issue_details`、`get_event_stacktrace`、`search_issue_events`、`get_issue_tag_values`（版・端末のタグの分布）など。どれも `event:read` | ソースで確認（packages/mcp-core/src/toolDefinitions.json） | 同上 |
| EU の組織 | 道具は `regionUrl` を引数に取り、`find_organizations` が組織の `regionUrl` を返す | ソースで確認（packages/mcp-core/src/schema.ts） | 同上 |
| Seer | Sentry の有料の追加機能（"Seer is an add-on to your Sentry subscription"）。nu-tori は無料のプランなので `seer` の道具は使えないと読める | 前半は本文で確認、後半は本文からの読み取り | https://docs.sentry.io/product/ai-in-sentry/seer.md |
| Sentry 自身のテレメトリ | ホストされた MCP は自分の観測に、道具の結果の JSON（`gen_ai.tool.call.result`）を記録する。読んだ課題の中身が Sentry の MCP の側のスパンにも残る | 本文で確認（TELEMETRY.md） | 同上 |

### 各ツールで OAuth をどう通すか

| 場所 | 通るか | 確かさ | 出典 |
|---|---|---|---|
| Claude Code の CLI・デスクトップ（ローカル） | 通る。`claude mcp add --transport http sentry https://mcp.sentry.dev/mcp` のあと `/mcp` か `claude mcp login sentry`。文書は Sentry をそのまま例に使う。claude.ai のコネクタとして足しても、CLI とデスクトップのローカルのセッションに届く | 本文で確認 | https://code.claude.com/docs/en/mcp.md （Authenticate with remote MCP servers、How connectors reach Claude Code） |
| Claude Code on the web | **claude.ai のコネクタとしてなら通る**。claude.ai のコネクタの一覧に「Sentry」（URL `https://mcp.sentry.dev/mcp`）がある。クラウドのセッションには「クラウドのホストが渡す」。サインインは claude.ai で済ませ、セッションの中ではサインインの手順を走らせない（"the session's proxy authenticates to the connector with the authorization you granted in claude.ai"）。コネクタの通信は Anthropic のサーバーを通るので、許可ドメインに足さなくてよい | 一覧は観察（MCP の登録簿の検索）、ほかは本文で確認 | mcp.md、https://code.claude.com/docs/en/cloud-environments.md （Network access の Note） |
| Claude Code on the web で `.mcp.json` の HTTP サーバーに OAuth | 分からない。セッションが「MCP サーバーへのサインインを待つ」ことがあるとは書くが、`.mcp.json` の OAuth をクラウドで終えられるかは書いていない。ブラウザの要るサインイン（AWS SSO など）は「Not supported」 | 本文を探したが記述なし（mcp.md、cloud-environments.md、claude-code-on-the-web.md） | 同上 |
| コネクタと `.mcp.json` が同じ URL のとき | `.mcp.json` などで足したサーバーが勝ち、コネクタは隠れる（"A server you've added in Claude Code takes precedence over a claude.ai connector that points at the same URL"） | 本文で確認 | mcp.md |
| Codex の CLI・アプリ（ローカル） | 通る。`[mcp_servers.sentry]` に `url` を書き、`codex mcp login sentry`。アプリは Settings > MCP servers の Authenticate | 本文で確認 | https://learn.chatgpt.com/docs/extend/mcp.md |
| Codex Cloud | 分からない（使えないと見るのがよい）。Cloud environments の文書に MCP もプラグインも出てこない。プラグインは「ChatGPT の web・デスクトップ・モバイルの Chat と Work、デスクトップアプリの Codex、Codex CLI」で使えると書き、Codex Cloud を挙げていない | 本文を探したが記述なし（cloud.md、environments/cloud-environments.md、extend/mcp.md、plugins.md） | https://learn.chatgpt.com/docs/environments/cloud-environments.md 、https://learn.chatgpt.com/docs/plugins.md |
| Cursor（ローカル） | 通る。Marketplace の項目を入れて OAuth か、`mcp.json` に URL を書く。Sentry の MCP のリポジトリに Cursor のプラグインの定義（`.cursor-plugin/plugin.json`）もある | 本文で確認、プラグインの定義は観察 | https://cursor.com/docs/mcp.md 、getsentry/toolkit の plugins/sentry-mcp |
| Cursor の Cloud Agents | 通る。cursor.com/agents の MCP のドロップダウンか、チームのダッシュボードで足す。"Cloud agents support OAuth for MCP servers that need it. OAuth is per-user"。HTTP のサーバーの設定と資格は VM に置かず、道具の呼び出しはバックエンドが中継する | 本文で確認（Sentry で試した記述は無い） | https://cursor.com/docs/cloud-agent/capabilities.md |

### OAuth を使わず `Sentry-Bearer` で渡す形

- Claude Code の `.mcp.json` は `headers` で `${VAR}` を展開する（本文で確認、mcp.md）。`"Authorization": "Sentry-Bearer ${NU_TORI_SENTRY_READ_TOKEN}"` と書ける。`ANTHROPIC_API_KEY`・`NPM_TOKEN` などの名前はリモートの `headers` では空として読むので、自分で名づけた変数を使う（本文で確認）
- Codex は `env_http_headers`（ヘッダーの名前 → 環境変数の名前）で渡せるが、値は変数の中身そのままなので、変数に `Sentry-Bearer <トークン>` まで入れる必要がある。`bearer_token_env_var` は `Bearer` を付けるので、この形には使えない（本文からの読み取り、extend/mcp.md の項目の説明から）
- Cursor は `headers` で `${env:NAME}` を展開する（本文で確認、mcp.md）
- この形はクラウドで秘密の値を環境変数に置くことになり、Codex Cloud ではそもそも MCP が使えないので、7つをまたぐ解にはならない（本文からの読み取り）

## 問い2: Sentry の公式の MCP を stdio で（`@sentry/mcp-server`）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 起動 | `npx @sentry/mcp-server@<版> --access-token=<トークン>`、または環境変数 `SENTRY_ACCESS_TOKEN` | 本文で確認 | README.md、packages/mcp-server/src/cli/usage.ts |
| トークンが無いとき | sentry.io ならデバイスコードの OAuth（RFC 8628）。端末（TTY）が要り、`~/.sentry/mcp.json` に保存する。TTY が無いと保存済みのものを使い、無ければ「先に `sentry-mcp auth login` を」と言って終わる。更新（refresh）は実装していない（Sentry のアクセストークンは 30 日） | 本文で確認 | docs/operations/stdio-auth.md |
| README が挙げるスコープ | `org:read`、`project:read`、`project:write`、`team:read`、`team:write`、`event:write`（"As of writing this is"）。書き込みを含むのは、課題の更新やプロジェクトの作成の道具のため | 本文で確認 | README.md |
| 読むだけで足りるか | 足りる。読む道具（`inspect`）が求めるのは `org:read`・`project:read`・`team:read`・`event:read` だけ。`--skills=inspect` で書き込みの道具を出さないようにできる。サーバーはトークンのスコープで道具を隠さず、足りないと Sentry の API が拒む | ソースで確認（toolDefinitions.json の `requiredScopes`、packages/mcp-core/src/permissions.ts）。「隠さない」は、スコープで道具を選ぶ処理が stdio の起動に見当たらないことからの読み取り | 同上 |
| 別の LLM の API キーは要るか | 要らない。README は「AI を使う検索の道具（`search_issues` など）は LLM の提供元が要り、無ければ使えない」と書くが、0.42.0 のソースでは提供元が無いと `search_issues` などは Sentry の検索の構文をそのまま使う（"Direct mode: use Sentry query syntax params as-is"）。README とソースが食い違っている | README は本文で確認、ソースで確認（tools/catalog/search-issues.ts、tools/support/search-events/search.ts） | 同上 |
| `EMBEDDED_AGENT_PROVIDER` | `openai`・`azure-openai`・`anthropic`・`openrouter`。未設定で `ANTHROPIC_API_KEY` などが1つだけあると、それを自動で使う（非推奨の動き）。2つ以上あるとエラー | 本文で確認 | docs/operations/embedded-agents.md |
| 自身のテレメトリ | `SENTRY_DSN`（か `DEFAULT_SENTRY_DSN`）があるとそこへ送り、道具の入出力も記録する（`recordInputs: true, recordOutputs: true`）。無ければ送らない | ソースで確認（packages/mcp-server/src/index.ts、cli/parse.ts） | 同上 |
| 版の固定 | 公式の例は `@latest` か版なし。`npx -y @sentry/mcp-server@0.42.0` のように固定できる | 前半は本文で確認、後半は本文からの読み取り | README.md |

nu-tori で使うなら、起動スクリプトで `ANTHROPIC_API_KEY`・`OPENAI_API_KEY`・`OPENROUTER_API_KEY`・`SENTRY_DSN` を外してから起動する（エージェントの環境の鍵を勝手に使わせない、道具の結果を Sentry へ送らせない）のがよい（本文からの読み取り、上の2行から）。

## 問い3: claude.ai のコネクタと、Claude Code の Sentry のプラグイン

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| claude.ai に Sentry のコネクタはあるか | ある。名前「Sentry」、説明「Search, query, and debug errors intelligently」、URL `https://mcp.sentry.dev/mcp` | 観察（MCP の登録簿の検索） | — |
| コネクタが届く場所 | CLI・VS Code・JetBrains は Claude Code が claude.ai から取りに行く。クラウドのセッションはホストが渡す。デスクトップアプリのローカルと SSH のセッションはアプリが渡す。どれも claude.ai の契約でログインしているときだけ（`ANTHROPIC_API_KEY` などが有効だと読まない） | 本文で確認 | mcp.md（Use MCP servers from claude.ai） |
| Team・Enterprise での追加 | "On Team and Enterprise plans, only admins can add servers." | 本文で確認 | 同上 |
| Claude Code のプラグイン（`getsentry/sentry-mcp` のマーケットプレイス） | `claude plugin marketplace add getsentry/sentry-mcp` と `claude plugin install sentry-mcp@sentry-mcp`。中身はリモートの MCP（`mcp.sentry.dev/mcp`）と、そこへ任せるサブエージェント `sentry-mcp` | 本文で確認 | README.md、docs/integrations/claude-code-plugin.md |
| プラグインはクラウドのセッションで使えるか | 使えない。リポジトリの `.claude/settings.json` で有効にしたプラグインも、利用者の設定だけで有効にしたプラグインも、クラウドのセッションは入れない（"A cloud session doesn't install the plugins a repository turns on under `enabledPlugins`"） | 本文で確認 | cloud-environments.md（What carries over from your setup） |
| Sentry の Agent Plugin（`npx @sentry/agent-plugin install`） | Claude Code・Cursor・Codex・Grok に、SDK の導入などのスキルとリモートの MCP を入れる。手元の機械にあるツールを探して入れる形 | 本文で確認 | https://docs.sentry.io/ai/agent-plugin.md |

## 問い4: sentry-cli（Rust）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 課題を読めるか | `sentry-cli issues list` は「Issue ID・Short ID・Title・Last seen・Status・Level」の表だけ。ほかに `resolve`・`mute`・`unresolve` | ソースで確認（src/commands/issues/list.rs ほか） | https://github.com/getsentry/sentry-cli |
| イベントを読めるか | `sentry-cli events list` は、プロジェクトのイベントの「Event ID・Date・Title」（`--show-user`、`--show-tags` で利用者とタグ）。スタックトレースを出すコマンドは無い | ソースで確認（src/commands/events/list.rs） | 同上 |
| 何に使うか | dSYM・ソースマップ・リリースなどを上げる道具。読む道具としては、件数や版をまたいだ傾向もスタックも取れない | 本文からの読み取り（上の2行と、文書の章立て https://docs.sentry.io/llms.txt の Sentry CLI の節から） | — |

## 問い5: Sentry の REST API を curl で叩く

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 認証 | `Authorization: Bearer <トークン>` | 本文で確認 | https://docs.sentry.io/api/auth.md |
| EU の組織の API の置き場 | `de.sentry.io`（US は `us.sentry.io`）。地域のドメインを使えば、選んだ置き場の中だけで処理される。組織を特定するメタデータは US にも複製され、互換の API のために使われる | 本文で確認 | https://docs.sentry.io/api.md 、https://docs.sentry.io/organization/data-storage-location.md |
| 課題の一覧 | `GET /api/0/organizations/{org}/issues/`（既定の検索は `is:unresolved`）。`event:read` など | 本文で確認 | https://docs.sentry.io/api/events/list-an-organizations-issues.md |
| 課題の詳細（件数、最初と最後の発生など） | `GET /api/0/organizations/{org}/issues/{issue_id}/`。`event:read` など | 本文で確認 | https://docs.sentry.io/api/events/retrieve-an-issue.md |
| スタックのあるイベント | `GET /api/0/organizations/{org}/issues/{issue_id}/events/{event_id}/`。`event_id` に `latest`・`oldest`・`recommended` を使える。`llmFormat=markdown`（か `json`・`xml`）で「LLM 向けに整えた `formatted` の欄」を足す。応答の `entries` の `exception` に `stacktrace` が入る。`event:read` など | 本文で確認 | https://docs.sentry.io/api/events/retrieve-an-issue-event.md |
| 版・端末の分布 | `List a Tag's Values for an Issue`（`/issues/{id}/tags/{key}/values/`） | 本文で確認（一覧の題） | https://docs.sentry.io/api/events.md |
| スコープの対応 | GET は `org:read`・`project:read`・`team:read`・`member:read`・`event:read`。PUT は `event:write`。イベントは変えられない | 本文で確認 | https://docs.sentry.io/api/permissions.md |

例（読み取りの1回分。`<org>` と `<issue_id>` は置き換える）:

```bash
curl -fsS -H "Authorization: Bearer $NU_TORI_SENTRY_READ_TOKEN" \
  "https://de.sentry.io/api/0/organizations/<org>/issues/<issue_id>/events/latest/?llmFormat=markdown"
```

curl は CLI が無くても動く一番下の手段で、Claude Code の API credentials（下）とも組み合わせられる（本文からの読み取り）。

## 問い6: Sentry の新しい公式の CLI（`sentry`）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 何か | "The command-line interface for Sentry. Built for developers and AI agents."。`gh` にならった `<名詞> <動詞>`、すべてのコマンドに `--json` | 本文で確認 | packages/cli/README.md、https://cli.sentry.dev |
| 入れ方 | `curl https://cli.sentry.dev/install -fsS \| bash`、Homebrew、`npm install -g sentry`、`npx sentry@<版>` | 本文で確認 | README.md |
| 課題とスタック | `sentry issue list`（`--query`、`--json --fields`）。`sentry issue view <ID> --json` は「課題の全体と、最新のイベントを `event` の下に」返す（"it includes the full issue plus the latest event under `event`, so you get everything in one call"）。`sentry issue events <ID> --full` は "Include full event body (stacktraces)"。`sentry event view <org/project/event-id>` もある | 本文で確認 | packages/cli/plugins/sentry-cli/skills/sentry-cli/SKILL.md、references/issue.md、references/event.md |
| 任意の API | `sentry api`（curl に似せた形で、認証を付けて呼ぶ）、`sentry schema`（API の一覧） | 本文で確認 | SKILL.md |
| 認証 | 環境変数 `SENTRY_AUTH_TOKEN`（別名 `SENTRY_TOKEN`）、または `sentry auth login`（OAuth、`~/.config/sentry/` に mode 600 で保存）。保存した OAuth があると環境変数より先に使う。`SENTRY_FORCE_ENV_TOKEN=1` で環境変数を先にする | 本文で確認 | README.md、src/lib/env-registry.ts の説明文 |
| 読むだけのログイン | `sentry auth login --read-only` は "Request only read-only OAuth scopes (project:read, org:read, event:read, member:read, team:read). Useful for handing tokens to AI agents or CI jobs that should not be able to mutate Sentry state." | 本文で確認 | references/auth.md |
| 組織とプロジェクトの決め方 | `SENTRY_ORG`、`SENTRY_PROJECT`（`org/project` の形も可）。無ければ `.sentryclirc`、`.env` やソースの中の DSN、ディレクトリ名から推す。ソースを探すのは深さ 3 まで | 本文で確認（説明文）、深さはソースで確認（src/lib/dsn/scan-options.ts の `DSN_MAX_DEPTH = 3`） | env-registry.ts |
| EU の組織 | API の応答の `links.regionUrl` で地域の URL に向き直す。`SENTRY_HOST`・`SENTRY_URL` は自前で動かす Sentry のためだけで、sentry.io の利用者は「設定しない」 | 前半はソースで確認（src/lib/region.ts）、後半は本文で確認 | 同上 |
| テレメトリと更新の確認 | 既定で CLI 自身の失敗の報告を Sentry に送る。`SENTRY_CLI_NO_TELEMETRY=1`（か `DO_NOT_TRACK=1`）で止める。`SENTRY_CLI_NO_UPDATE_CHECK=1` で裏の更新の確認を止める | 本文で確認 | env-registry.ts の説明文 |
| トークンの形の扱い | `sntrys_`（組織のトークン）、`sntryu_`（個人のトークン）、それ以外（OAuth か古い形）に分けるだけで、知らない形も Bearer として送る | ソースで確認（src/lib/token-type.ts） | 同上 |
| エージェント向けの注意 | 最新のイベントの `request` には cookie やヘッダーが入りうるので、`--fields` で欲しい欄だけ取る、と書く | 本文で確認 | SKILL.md |
| 使えないもの | `sentry issue explain`・`plan` は Seer（有料の追加機能）を使う | 本文からの読み取り（SKILL.md の「Seer AI Integration」と Seer の料金の記述から） | — |

## 場所ごとの表: どこに秘密の値を置き、どこへ出られるか

| 場所 | 秘密の値を置く場所 | sentry.io・de.sentry.io へ出られるか | 確かさ | 出典 |
|---|---|---|---|---|
| Mac（3つのツールすべて） | `sentry auth login --read-only` の保存（`~/.config/sentry/`）。トークンを使うなら、各自のシェルの環境変数 | 出られる | 本文で確認 | CLI の README.md、references/auth.md |
| Claude Code on the web: 環境変数 | 環境の「Environment variables」（`.env` の形）。セッションの中のどのコマンドからも読める。「環境を使う人は誰でも値を読める」。共有の環境には秘密を置かない | 既定の Trusted に `sentry.io` は無い。Custom で `sentry.io` と `*.sentry.io` を足し、「Also include default list」を入れて npm も残す | 本文で確認（許可リストに無いことは一覧の確認） | https://code.claude.com/docs/en/cloud-environments.md |
| Claude Code on the web: API credentials | Pro・Max だけ（Team・Enterprise はまだ無い）。キーは VM にもコマンドにも入らず、Anthropic の agent proxy が、登録したホストへの要求に付ける。登録したホストは許可リストに関係なく出られる。ヘッダーの名前と接頭辞（既定は `Authorization` と `Bearer`）を変えられる | ホストに `sentry.io`、`*.sentry.io` を登録すれば出られる | 本文で確認 | 同上（Add API credentials） |
| Claude Code on the web: claude.ai のコネクタ | claude.ai で OAuth を済ませる。値はセッションに入らない | コネクタの通信は Anthropic のサーバーを通るので、許可リストは要らない | 本文で確認 | 同上（Network access の Note）、mcp.md |
| Codex Cloud: Environment variable | プログラムに値そのものを渡す | 「Allow Codex to access internet」を入れ、Additional allowed domains に `sentry.io`、`de.sentry.io` を足す。「Package managers」の一覧に Sentry は無い。登録したドメインの `www` 以外の下位のドメインは、それぞれ足す | 本文で確認 | https://learn.chatgpt.com/docs/environments/cloud-environments.md |
| Codex Cloud: Network secret | プログラムには置き換え用の値（placeholder）が渡り、proxy が許可したドメインへの HTTPS（443）の要求で本物に差し替える。保存すると、その宛先が許可に足される。Personal vault に各自の値として置くこともできる | 宛先に `sentry.io`、`de.sentry.io` を書く | 本文で確認 | 同上 |
| Codex Cloud の既定のネット | 新しい Cloud environments では、インターネットは「Allow Codex to access internet」を入れて使う形で書かれている。Legacy の文書は「エージェントの段階では既定で切る」 | 前半は本文からの読み取り、後半は本文で確認 | 同上、https://learn.chatgpt.com/docs/cloud/internet-access.md |
| Cursor の Cloud Agents | ダッシュボードの Secrets。環境変数としてエージェントに渡る。環境ごとの Secrets もある。HTTP の MCP の `headers` は暗号化して保存し、読み戻せない | 既定で全部に出られる（"The agent has internet access by default"）。絞るなら「Default + allowlist」などに足す | 本文で確認 | https://cursor.com/docs/cloud-agent/setup.md 、https://cursor.com/docs/cloud-agent/security-network.md 、capabilities.md |

### 候補ごとに、7つの場所で動くか

```
                       Mac: Claude  Mac: Codex  Mac: Cursor  Claude web  Codex Cloud  Cursor Cloud
sentry CLI（勧める）      ○           ○           ○           ○※1         ○※2          ○
curl で REST API          ○           ○           ○           ○           ○※2          ○
リモート MCP（OAuth）     ○           ○           ○           ○※3         ×（記述なし）  ○※4
stdio の MCP              ○           ○           ○           ○※5         ×（記述なし）  △※6
sentry-cli（Rust）        スタックを読めないので対象外
```

- ※1 環境変数にトークンを置き、Custom で `sentry.io`・`*.sentry.io` を許可する。API credentials だけで動かすには、CLI が手元にトークンが無いと送る前に止まる（終了コード 10〜19 は認証の失敗、SKILL.md）ので、仮のトークンを置いたうえで proxy が `Authorization` を差し替えるかを確かめる必要がある（本文を探したが記述なし。差し替えか追加かは cloud-environments.md に書かれていない）
- ※2 Network secret の placeholder を CLI が Bearer として送り、proxy が差し替える、という読み。動かしては確かめていない（本文からの読み取り、token-type.ts と cloud-environments.md から）
- ※3 claude.ai のコネクタとして。`.mcp.json` に書いた場合は※を付けられない（上の問い1）
- ※4 Cloud Agents のダッシュボードで足し、利用者ごとに OAuth
- ※5 `.mcp.json` を読むので、環境変数にトークンを置けば起動する（本文からの読み取り）
- ※6 Cloud Agents はリポジトリの `.cursor/mcp.json` を読むと書いていない。ダッシュボードに stdio のサーバーとして足せば VM の中で動く（"We cannot verify that a stdio server will run successfully until a cloud agent is launched"）（本文で確認）

## nu-tori への当てはめ

ここは、上の表からの読み取り。決めるのは開発者で、決めたことはストック（`docs/agents/tooling.md` など）に書く。

### 勧める形

```
エージェント ──Bash──> scripts/sentry ──npx──> sentry@0.46.0 ──HTTPS──> sentry.io / de.sentry.io
                         │
                         ├─ 版、テレメトリの停止、組織の slug をここ1か所に書く
                         └─ トークン: NU_TORI_SENTRY_READ_TOKEN があれば使う
                                      無ければ Mac の `sentry auth login --read-only` の保存を使う
（任意）各自の設定にだけ、Sentry のリモート MCP（OAuth）。リポジトリの MCP の設定には置かない
```

### 置くファイル

`scripts/sentry`（実行できるようにする。`<org-slug>` は Sentry の組織の slug で、秘密ではない）:

```bash
#!/usr/bin/env bash
# エージェントと人が Sentry の課題・イベント・スタックを読む `sentry` CLI。版と設定を、ここ1か所に置く
set -euo pipefail

# CLI 自身の失敗の報告と、裏の更新の確認を止める
export SENTRY_CLI_NO_TELEMETRY=1
export SENTRY_CLI_NO_UPDATE_CHECK=1
export SENTRY_ORG="${SENTRY_ORG:-<org-slug>}"

# 読むだけのトークンは、dSYM を上げる組織のトークン（Xcode Cloud の SENTRY_AUTH_TOKEN）と混ざらない名前で受け取る
if [ -n "${NU_TORI_SENTRY_READ_TOKEN:-}" ]; then
    export SENTRY_AUTH_TOKEN="$NU_TORI_SENTRY_READ_TOKEN"
    export SENTRY_FORCE_ENV_TOKEN=1
else
    unset SENTRY_AUTH_TOKEN SENTRY_TOKEN
fi

exec npx -y sentry@0.46.0 "$@"
```

ルートの `AGENTS.md`（または `docs/agents/tooling.md`）に足す一文の例:

```
- Sentry のクラッシュ（課題・イベント・スタック・端末・版・件数）は `scripts/sentry` で読む（例: `scripts/sentry issue list <project> --json`、`scripts/sentry issue view <短い ID> --json --fields ...`、`scripts/sentry issue events <短い ID> --full`）。書き込みのコマンド（resolve、archive など）は使わない。読んだイベントの中身は、公開の Issue・PR・コメントに貼らない
```

- getsentry/toolkit の `packages/cli/plugins/sentry-cli/skills/sentry-cli/` にエージェント向けの skill がある。入れるなら `.agents/skills/` に置いて `.claude/skills/` からリンクする今の決まりに従う（`docs/agents/tooling.md`）。版は CLI と同じ 0.46.0 のものにそろえる
- `.mcp.json`・`.codex/config.toml`・`.cursor/mcp.json` には何も足さない
- 版を上げるときは `scripts/sentry` の1行だけを直す。0.x で破壊的な変更がありうるので、上げたら `issue view --json` の欄の名前を確かめる（本文からの読み取り）

### 開発者が手でやること

1. **トークンを作る（クラウドで使うときだけ）**: sentry.io の Personal Tokens（アカウントのメニュー > Personal Tokens、https://sentry.io/settings/account/api/auth-tokens/ ）で、スコープ `org:read`・`project:read`・`team:read`・`event:read`・`member:read` だけを選んで作る。あとから変えられないので、足りなければ作り直す。用途ごとに分けるのが Sentry の勧め（"We recommend using a separate auth token for each use case"）なので、クラウド用に1つ作り、各クラウドで同じものを使うか分けるかを決める
2. **Mac**: `scripts/sentry auth login --read-only` を一度走らせる（ブラウザで許可）。トークンの文字列は扱わない
3. **Claude Code on the web**: 個人の環境（共有しない）の Environment variables に `NU_TORI_SENTRY_READ_TOKEN=<トークン>`。Network access を Custom にし、`sentry.io` と `*.sentry.io` を足し、「Also include default list of common package managers」を入れる。あわせて claude.ai の Settings > Connectors で Sentry のコネクタをつないでおけば、MCP でも読める（任意）
4. **Codex Cloud**: 環境の Network secrets（か Personal vault）に、キー `NU_TORI_SENTRY_READ_TOKEN`、許可ドメイン `sentry.io`、`de.sentry.io`。インターネットを有効にする。動かなければ（※2）Environment variable に変える
5. **Cursor の Cloud Agents**: ダッシュボードの Cloud Agents > Secrets に `NU_TORI_SENTRY_READ_TOKEN`。ネットを絞っているなら `sentry.io`、`de.sentry.io` を足す
6. 最初に各場所で `scripts/sentry issue list <project> --limit 1 --json` を一度走らせ、動いたかを `docs/agents/tooling.md` に書く

### 動かないところ、確かめていないところ

- 実際の Sentry の組織に向けては、どの道具も動かしていない
- Codex Cloud の Network secret の placeholder で CLI が通るか（※2）、Claude Code の API credentials だけで CLI が通るか（※1）は、文書だけでは決まらない
- Codex Cloud で MCP を使う道は、文書に無い。リモート MCP は Codex Cloud では使えないものとして扱う
- Claude Code on the web で、`.mcp.json` に書いたリモート MCP の OAuth を終えられるかは書かれていない（コネクタなら通る）
- CLI の DSN からの推定は深さ 3 までで、`ios/NuTori/Observability/ObservabilityKeys.swift` に届くかは確かめていない。`SENTRY_ORG` を起動スクリプトで決め、プロジェクトは引数で渡す前提にした
- 読んだクラッシュの中身はエージェントの会話（各社のサーバー）に入る。ADR-0017 は記録の中身を観測の道具に送らないと決めているので、Sentry のイベントに記録の中身は入っていないはずだが、公開リポジトリの Issue・PR に貼らない決まりは、上の `AGENTS.md` の一文で別に書く必要がある（本文からの読み取り）

## `agent-tools-setup.md` で書き直す点

| 前の記述 | 今の状態（2026-10-03） | 確かさ | 出典 |
|---|---|---|---|
| Codex cloud の環境の出典に `learn.chatgpt.com/docs/environments/cloud-environment.md` と `cloud/internet-access.md` を引き、setup script や既定の image（universal）を書いている | この2つは「Codex Cloud (Legacy)」になった（"We plan to deprecate this experience"）。今の Codex Cloud は `environments/cloud-environments.md` で、Codex が環境を調べて Install script と Start skill を作り、Publish する形。Environment variables と Network secrets、Personal vault、VPN（Tailscale）がある | 本文で確認 | https://learn.chatgpt.com/docs/environments/cloud-environments.md |
| 問い1「Codex cloud でリポジトリのスキルを読むかは書かれていない」 | 書かれた: "Skills stored in your repository are available in cloud tasks. Personal skills from your local computer aren't synced to cloud environments." | 本文で確認 | 同上（Current limitations） |
| 問い6「Codex cloud で Swift 6.4 は setup script で入れる」 | 新しい Cloud environments では、版の指定は会話で頼み、Codex が Install script に書く形。`CODEX_ENV_SWIFT_VERSION` などの話は Legacy のもの | 本文で確認 | 同上 |
| Claude Code on the web の秘密の値（記述なし） | Pro・Max には API credentials があり、キーを VM に入れずにホストごとに付けられる。環境変数は「環境を使う人は誰でも読める」 | 本文で確認 | https://code.claude.com/docs/en/cloud-environments.md |
| Claude Code on the web のプラグイン（記述なし） | リポジトリの `enabledPlugins` のプラグインも、利用者の設定だけのプラグインも、クラウドのセッションは入れない。claude.ai で有効にしたスキルは読む | 本文で確認 | 同上 |
| Cursor の Cloud Agents の MCP（「ダッシュボードで足す」まで） | HTTP の MCP の OAuth は利用者ごとに通る。HTTP の設定と資格は VM に入らない。stdio は VM の中で動く | 本文で確認 | https://cursor.com/docs/cloud-agent/capabilities.md |

## 出典一覧

Sentry（2026-10-03）
- getsentry/toolkit（旧 getsentry/sentry-mcp、6054887）: https://github.com/getsentry/toolkit — README.md、server.json、TELEMETRY.md、docs/operations/stdio-auth.md、docs/operations/embedded-agents.md、docs/specs/sentry-bearer-cloudflare-auth.md、docs/integrations/claude-code-plugin.md、packages/mcp-core/src/（skills.ts、scopes.ts、permissions.ts、toolDefinitions.json、tools/catalog/search-issues.ts、tools/support/search-events/search.ts）、packages/mcp-server/src/（index.ts、cli/usage.ts、cli/parse.ts）、packages/cli/（README.md、src/lib/env-registry.ts、src/lib/region.ts、src/lib/token-type.ts、src/lib/dsn/scan-options.ts、plugins/sentry-cli/skills/sentry-cli/ の SKILL.md と references）
- getsentry/sentry-cli（a7298b0）: https://github.com/getsentry/sentry-cli — src/commands/issues/、src/commands/events/
- npm: https://registry.npmjs.org/sentry 、https://registry.npmjs.org/@sentry/mcp-server
- docs.sentry.io: https://docs.sentry.io/llms.txt 、Auth Tokens https://docs.sentry.io/account/auth-tokens.md 、API https://docs.sentry.io/api.md 、Authentication https://docs.sentry.io/api/auth.md 、Permissions & Scopes https://docs.sentry.io/api/permissions.md 、Events & Issues https://docs.sentry.io/api/events.md （Retrieve an Issue Event、Retrieve an Issue、List an Organization's Issues）、Data Storage Location https://docs.sentry.io/organization/data-storage-location.md 、Agent Plugin https://docs.sentry.io/ai/agent-plugin.md 、Coding Agents https://docs.sentry.io/integrations/coding-agents.md 、Seer https://docs.sentry.io/product/ai-in-sentry/seer.md
- 新しい CLI の文書サイト（README が指す。この調査では開いていない）: https://cli.sentry.dev

Anthropic（Markdown 版。2026-10-03）
- MCP: https://code.claude.com/docs/en/mcp.md
- Configure cloud environments: https://code.claude.com/docs/en/cloud-environments.md
- Use Claude Code in the cloud: https://code.claude.com/docs/en/claude-code-on-the-web.md
- Changelog: https://code.claude.com/docs/en/changelog.md
- claude.ai のコネクタの一覧: MCP の登録簿の検索（観察）

OpenAI（Markdown 版。2026-10-03）
- llms.txt: https://developers.openai.com/codex/llms.txt
- Cloud environments: https://learn.chatgpt.com/docs/environments/cloud-environments.md
- Codex Cloud (Legacy): https://learn.chatgpt.com/docs/environments/cloud-environment.md 、internet access: https://learn.chatgpt.com/docs/cloud/internet-access.md
- Codex Cloud: https://learn.chatgpt.com/docs/cloud.md
- Model Context Protocol: https://learn.chatgpt.com/docs/extend/mcp.md
- Plugins: https://learn.chatgpt.com/docs/plugins.md

Cursor（Markdown 版。2026-10-03）
- MCP: https://cursor.com/docs/mcp.md
- Cloud Agents: https://cursor.com/docs/cloud-agent.md 、capabilities: https://cursor.com/docs/cloud-agent/capabilities.md 、setup: https://cursor.com/docs/cloud-agent/setup.md 、security and network: https://cursor.com/docs/cloud-agent/security-network.md
- Run modes（既定の許可ドメイン）: https://cursor.com/docs/agent/security/run-modes.md
