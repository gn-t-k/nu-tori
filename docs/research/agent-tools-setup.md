# Claude Code・Codex・Cursor を同じリポジトリで使うための設定（スキル、MCP、AGENTS.md、bot の PR、依存の更新、クラウドの環境）

調査日: 2026-09-26
対象: nu-tori（公開のモノレポ。`ios/` と `server/`）を、Claude Code・Codex・Cursor の3つで並べて使うときに、リポジトリに置く設定がそれぞれにどう読まれるか。前提は `docs/research/agent-ios-verification.md`（2026-09-24。Mac の上の検証の道具は Xcode の MCP と MobileBuildMCP）

> **確認の方法と限界**
> - Claude Code は code.claude.com/docs の Markdown 版（`.md`）と `llms-full.txt`、changelog を読んだ。Codex は developers.openai.com/codex/llms.txt から辿れる learn.chatgpt.com/docs の Markdown 版と `llms-full.txt` を読んだ。Cursor は cursor.com/docs の Markdown 版を読んだ。Apple の文書は JSON（`https://developer.apple.com/tutorials/data/<パス>.json`）で本文を読んだ。
> - GitHub の仕組みは、github/docs リポジトリの Markdown 原稿と REST API の説明データ（2026-09-25 のコミット 18945a3）、github.blog の changelog の HTML を読んだ。出典にはふつうの docs.github.com の URL を書く。
> - 公式リポジトリは clone して文書とソースを読んだ: getsentry/XcodeBuildMCP（MobileBuildMCP、v2.7.1、d13ff0c）、getsentry/xcodebuildmcp.com（文書サイトの原稿、78e43ff）、dependabot/dependabot-core（f3a79fa）、renovatebot/renovate（e02925f）、openai/codex-universal（47f4f0e）、swiftlang/swiftly（468a23e）。npm の版は registry.npmjs.org の JSON で確かめた。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。文書ではなくソースコードで確かめたものは「ソースで確認」と書き、ファイルを添える（ソースは次の版で変わりうるので、文書の約束より弱い）。本文やソースの記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。本文を探しても記述が無かったものは「本文を探したが記述なし」と書き、探したページを添える。
> - このリポジトリの GitHub の設定は、この調査のセッションから GitHub の REST API で読んだ（`pull_request_creation_policy` が `collaborators_only`、最近の Issue と PR はすべて locked）。interaction limits の設定は権限が足りず読めなかった。
> - Mac、Codex、Cursor での動作確認はしていない（この調査は Linux の Claude Code on the web で行った）。二次情報（ブログ、記事、SNS）は使っていない。
> - 状況は速く動いている。MobileBuildMCP は 2026-09-23 に改名したばかりで、文書サイトの原稿がまだ旧名のまま、など、2026-09-26 時点の状態を書いた。

## 結論の要約

- **スキル**（本文で確認）: Codex は `.agents/skills/`、Claude Code は `.claude/skills/` だけを読む。Cursor は両方と `.codex/skills/` を読む。Claude Code と Codex はシンボリックリンクのスキルのフォルダを辿ると明記している。Cursor はシンボリックリンクと、同じスキルが2か所から見えるときの扱いを書いていない。このリポジトリでは `.claude/skills/model-based-ui-design` だけが実体で `.agents/skills/` に無いので、Codex からは見えない（本文からの読み取り）。
- **MCP のリポジトリの設定**（本文で確認）: Claude Code は `.mcp.json`、Codex は `.codex/config.toml`（信頼したプロジェクトだけ）、Cursor は `.cursor/mcp.json`。3つとも OS で絞る項目は無い。Claude Code はクラウドのセッションでも `.mcp.json` を承認なしで読む。起動できないサーバーは「失敗」と表示され、セッションは続く、と読める（セッションが止まるのは setup script が失敗したときだけと書いている）。Codex cloud と Cursor の Cloud Agents がリポジトリの MCP の設定を読むかは書かれていない（Cursor の Cloud Agents はダッシュボードで MCP を足す）。
- **MobileBuildMCP**: 最新は 2.7.1（2026-09-23）。起動は `npx -y mobilebuildmcp@latest mcp`（本文で確認）。Sentry への送信を止める環境変数は、改名後は `MOBILEBUILDMCP_SENTRY_DISABLED=true`。旧名の `XCODEBUILDMCP_SENTRY_DISABLED` は 2.7.1 のソースでは読まれない（ソースで確認）。設定ファイルは、サーバーを起動したディレクトリの `.mobilebuildmcp/config.yaml`。ここで使う道具のまとまり（`enabledWorkflows`）、既定のプロジェクトとスキーム、`sentryDisabled: true` を書ける（ソースで確認）。文書サイトの原稿はまだ旧名（`xcodebuildmcp@latest`、`.xcodebuildmcp/`）のまま。版は固定するのがよい（本文からの読み取り）。
- **AGENTS.md**（本文で確認）: Claude Code は v2.1.277 から `AGENTS.md` を直接読む（`CLAUDE.md` が無いとき）。下のディレクトリの `AGENTS.md` は、そこのファイルを Read で開いたときに読む。Codex は起動時に、リポジトリのルートから今のディレクトリまでの `AGENTS.md` を読む。ルートで起動すると `ios/AGENTS.md` は読まない。Cursor は、下のディレクトリのファイルを扱うときに、そこの `AGENTS.md` を足す。このリポジトリに `CLAUDE.md` は要らない。`CLAUDE.local.md` を置くと、Claude Code は `AGENTS.md` を読まなくなる。
- **PR の作成を共同作業者に絞った設定と bot**（本文を探したが記述なし）: GitHub の文書は「共同作業者（書き込み権限のあるユーザー）だけが PR を作れる」と書くだけで、GitHub App や Dependabot、Renovate がどうなるかは、GitHub・Renovate・Codex・Cursor のどの文書にも書かれていない。locked の会話で bot がコメントできるかも同じ。このリポジトリは両方を使っているので、各ツールで一度試して確かめる必要がある。
- **Swift 6.4**: Codex cloud の既定の image（codex-universal）の Swift は 5.10、6.1、6.2 で、`CODEX_ENV_SWIFT_VERSION` はこの中から選ぶだけ。6.4 は setup script で入れる（本文からの読み取り）。Cursor の Cloud Agents は `.cursor/environment.json` の `install` か Dockerfile で入れられる（本文で確認）。Claude Code on the web は setup script で入れる。既定の許可ドメインに `download.swift.org` は無いので、Custom で足す（本文からの読み取り）。swiftly は `.swift-version` を今のディレクトリと親から探し、子のディレクトリは見ない（本文とソースで確認）。
- **Claude Code の Auto-fix**（本文で確認）: 自分で作っていない PR でも、URL を貼って頼めば見張れる。Claude GitHub App が要る。push できるのはセッションの作業ブランチだけ。Dependabot の PR に commit を足すと、Dependabot はその PR を rebase しなくなる（`[dependabot skip]` をメッセージに入れれば上書きを許す）。
- **Dependabot と Renovate**: Dependabot は、SHA で固定した `uses:` を同じ行のコメントの版ごと更新する（本文で確認）。ワークフローの `container:` のイメージは読まない（ソースで確認）。Swift はソースでは Xcode のプロジェクトの依存も扱うが、文書に記述は無く、Dependabot の Swift は 6.3.1 なので `swift-tools-version: 6.4` の `Package.swift` は読めないおそれがある（ソースからの読み取り）。Renovate は `uses:` の SHA とコメントに加えて、`container:` と `services:` のイメージも更新し、正規表現の custom manager で版と SHA-256 の組も追える（本文とソースで確認）。Mend Renovate App は公開・非公開とも無料の枠がある（本文で確認）。
- nu-tori への当てはめは末尾の「nu-tori への当てはめ」。

## 前提: 2026-09-26 時点の状態とこのリポジトリ

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Claude Code の最新 | 2.1.283（2026-09-25）。この調査のセッションも 2.1.283 で、ルートの `AGENTS.md` が読み込まれていた | 本文で確認（版）、観察（読み込み） | https://code.claude.com/docs/en/changelog.md |
| MobileBuildMCP の最新 | npm の `mobilebuildmcp` は `latest` が 2.7.1（2026-09-23 20:21 UTC）、`beta` が 2.7.1-beta.1 | 本文で確認 | https://registry.npmjs.org/mobilebuildmcp 、https://github.com/getsentry/XcodeBuildMCP （CHANGELOG 2.7.1） |
| このリポジトリのスキル | `.agents/skills/` に mattpocock/skills の 25 個（`skills-lock.json` で管理）。`.claude/skills/` はその各フォルダへのシンボリックリンク（git には mode 120000 で入っている）と、実体のフォルダ `model-based-ui-design` 1つ | 観察（`ls -la .claude/skills`、`git ls-files -s`） | — |
| このリポジトリの指示のファイル | ルート、`ios/`、`server/` に `AGENTS.md`（8,084、18,196、22,662 バイト）。`CLAUDE.md` はどこにも無い | 観察 | — |
| このリポジトリの GitHub の設定 | `pull_request_creation_policy: collaborators_only`。`.github/workflows/lock-conversations.yml` が Issue と PR を開いたときにロックする | 観察（REST API、ワークフロー） | — |
| ワークフローの固定 | `uses:` は SHA ＋ 版のコメント（`actions/checkout@3d3c… # v7.0.1`）、`ios` のジョブは `container: swift:6.4.0-noble@sha256:…`。`scripts/check` は SwiftLint の版（`swiftlint_version=0.65.1`）と、配布物ごとの SHA-256 を3つ持つ | 観察 | `.github/workflows/check.yml`、`scripts/check` |

## 問い1: スキルをどこから読むか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Claude Code のプロジェクトのスキル | `.claude/skills/<skill-name>/SKILL.md`（プロジェクト）と `<subdir>/.claude/skills/<skill-name>/SKILL.md`（下のディレクトリ。そこで作業すると読む） | 本文で確認 | https://code.claude.com/docs/en/skills.md |
| Claude Code は `.agents/skills/` を読むか | 読まない。スキルの置き場の表に `.agents/` は無い。`AGENTS.md` の節には「`.agents/` ディレクトリの下のものは読まない」（"Not read: … anything under a `.agents/` directory"） | 本文で確認（前者は記述が無いことの確認） | 同上、https://code.claude.com/docs/en/memory.md |
| Claude Code はシンボリックリンクを辿るか | 辿る。"a `<skill-name>` entry in the enterprise, personal, or project location can be a symlink to a directory elsewhere on disk. Claude Code reads `SKILL.md` from the target and loads the skill once even if several locations point at the same target." | 本文で確認 | skills.md |
| Claude Code on the web で読むか | 読む（リポジトリの `.claude/skills/` は clone に含まれる）。`~/.claude/skills/` は読まない | 本文で確認 | https://code.claude.com/docs/en/cloud-environments.md |
| Codex のプロジェクトのスキル | "Codex scans `.agents/skills` in every directory from your current working directory up to the repository root."（`$CWD/.agents/skills`、親、`$REPO_ROOT/.agents/skills`）。ほかに `$HOME/.agents/skills`、`/etc/codex/skills` | 本文で確認 | https://learn.chatgpt.com/docs/build-skills.md |
| Codex は `.claude/skills/` を読むか | 読まない（置き場の表に無い） | 本文を探したが記述なし（build-skills.md、skills-and-plugins.md） | 同上 |
| Codex はシンボリックリンクを辿るか | 辿る。"Codex supports symlinked skill folders and follows the symlink target when scanning these locations." | 本文で確認 | 同上 |
| Codex のどの面で使えるか | "Standalone skills are available in the ChatGPT desktop app, Codex CLI, and IDE extension." Codex cloud でリポジトリのスキルを読むかは書かれていない | 前半は本文で確認、cloud は本文を探したが記述なし（cloud.md、cloud-environment.md、llms-full.txt） | build-skills.md、https://learn.chatgpt.com/docs/cloud.md |
| Cursor のプロジェクトのスキル | `.agents/skills/` と `.cursor/skills/`。互換のため `.claude/skills/`、`.codex/skills/` も読む（"For compatibility, Cursor also loads skills from Claude and Codex directories"）。リポジトリの中のどこにある `.cursor/skills/`・`.agents/skills/` も拾い、そのディレクトリのファイルを扱うときだけ出す | 本文で確認 | https://cursor.com/docs/skills.md |
| Cursor はシンボリックリンクを辿るか、同じスキルが2か所にあるとどうなるか | どちらも書かれていない | 本文を探したが記述なし（skills.md） | 同上 |
| Cursor の Cloud Agents で読むか | 個人の `~/.cursor/skills/` は「Sync Skills for Cloud Agents」で同期する。リポジトリのスキルは、self-hosted worker について「リポジトリのプロジェクトのスキルを使う」（"use project skills from the repo"）とあり、clone したリポジトリのスキルは読むと読める | 前半は本文で確認、後半は本文からの読み取り | 同上 |
| このリポジトリでの見え方 | Claude Code: `.claude/skills/` の 26 個。Codex: `.agents/skills/` の 25 個（`model-based-ui-design` は見えない）。Cursor: 両方を読むので 26 個、うち 25 個は2か所から見える | 本文からの読み取り（上の各行と、このリポジトリの配置から） | — |

## 問い2: リポジトリに置く MCP の設定

### Claude Code

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 置き場と形 | リポジトリのルートの `.mcp.json`。`{"mcpServers": {"<name>": {"type": "stdio", "command": "…", "args": […], "env": {…}}}}`。`type` の無い項目は stdio として読む | 本文で確認 | https://code.claude.com/docs/en/mcp.md |
| 環境変数の展開 | `command`、`args`、`env`、`url`、`headers` で `${VAR}` と `${VAR:-default}` を展開する。未設定で既定値も無いと、警告を出して `${VAR}` のまま使う | 本文で確認 | 同上 |
| 承認 | 対話のセッションでは使う前に承認を求める（"prompts for approval in interactive sessions before using project-scoped servers"）。リポジトリに commit した `enableAllProjectMcpServers`・`enabledMcpjsonServers` は、信頼していないフォルダでは無視する（"A cloned repository can't approve its own servers"） | 本文で確認 | 同上 |
| クラウドのセッションで読むか | 読む。承認なしで読み込む（"In `claude -p` runs, Agent SDK sessions, and cloud sessions, Claude Code can't show that prompt: it loads project-scoped servers without asking"）。リポジトリが1つのセッションで読む（"Yes, in a session with one repository"） | 本文で確認 | mcp.md、cloud-environments.md |
| 起動できないとき | サーバーは「✘ Failed to connect」などの状態で表示される。既定ではサーバーは裏で接続し（"Other servers connect in the background by default"）、tool search（既定で有効）のときは「どのサーバーが失敗したか」を Claude に伝える。stdio のサーバーは自動では再接続しない。セッションそのものが止まるとは書いていない。クラウドでセッションが始まらないのは setup script が 0 以外で終わったとき（"if the script exits non-zero, the session fails to start"） | 本文で確認。「Linux で `xcrun` が無くてもセッションは続く」は本文からの読み取り（失敗の扱いの記述と、止まる条件の記述から） | mcp.md、cloud-environments.md |
| 使わせないようにする | `disabledMcpjsonServers` に名前を書く（どの権限モードでも止める）、`--strict-mcp-config`、`--setting-sources` でプロジェクトの設定を外す | 本文で確認 | mcp.md、https://code.claude.com/docs/en/settings-reference.md |
| macOS だけにする項目 | 無い。設定の項目に OS の条件は見当たらない | 本文を探したが記述なし（mcp.md、settings-reference.md） | — |
| サーバーの作業ディレクトリ | サーバーの環境に `CLAUDE_PROJECT_DIR`（プロジェクトのルート）を入れる。stdio のサーバーをどのディレクトリで起動するかは書いていない | 前半は本文で確認、後半は本文を探したが記述なし | mcp.md |

### Codex

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 置き場と形 | `~/.codex/config.toml` か、プロジェクトの `.codex/config.toml`（"trusted projects only"）。`[mcp_servers.<name>]` に `command`（必須）、`args`、`env`、`env_vars`、`cwd`。プロジェクトの `.codex/config.toml` はルートから今のディレクトリまで重ね、近いものが勝つ | 本文で確認 | https://learn.chatgpt.com/docs/extend/mcp.md 、https://learn.chatgpt.com/docs/config-file/config-basic.md |
| 信頼 | 信頼していないプロジェクトでは `.codex/` の層（設定、hooks、rules）を読まない。`projects.<path>.trust_level` で `"trusted"`・`"untrusted"` を決める | 本文で確認 | config-basic.md、https://learn.chatgpt.com/docs/config-file/config-reference.md |
| 起動できないとき | `required = true` のサーバーだけが、初期化できないと起動を失敗させる（"Set `true` to make startup fail if this enabled server can't initialize"）。任意のサーバーは既定で 1000 ms だけ待つ（`mcp_optional_startup_grace_ms`） | 本文で確認 | extend/mcp.md |
| 使える面 | "The ChatGPT desktop app, Codex CLI, and IDE extension support MCP servers and share MCP configuration." Codex cloud がリポジトリの `.codex/config.toml` の MCP を読むかは書かれていない | 前半は本文で確認、cloud は本文を探したが記述なし（cloud.md、cloud-environment.md、extend/mcp.md、llms-full.txt） | 同上 |
| macOS だけにする項目 | 無い（`enabled = false` で止めることはできる） | 本文を探したが記述なし（config-reference.md） | — |

### Cursor

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 置き場と形 | プロジェクトは `.cursor/mcp.json`、全体は `~/.cursor/mcp.json`。`{"mcpServers": {"<name>": {"type": "stdio", "command": "…", "args": […], "env": {…}}}}`。`envFile` も使える。展開は `${env:NAME}`、`${workspaceFolder}` など | 本文で確認 | https://cursor.com/docs/mcp.md |
| 失敗したとき | "Cursor isolates server failures to prevent one server from affecting others." | 本文で確認 | 同上 |
| CLI | CLI は `mcp.json` をそのまま読む。承認を飛ばすのは `agent --approve-mcps` | 本文で確認 | https://cursor.com/docs/cli/using.md 、https://cursor.com/docs/cli/mcp.md |
| Cloud Agents | cursor.com/agents の MCP のドロップダウンか、チームのダッシュボードで足す。stdio は VM の中で動き、「エージェントを起動するまで動くか確かめられない」（"We cannot verify that a stdio server will run successfully until a cloud agent is launched"）。MCP の認証の失敗は `mcp_auth_error` で「その道具を飛ばして実行を続けた」と記録する。リポジトリの `.cursor/mcp.json` を Cloud Agents が読むかは書かれていない | 前半は本文で確認、最後は本文を探したが記述なし（cloud-agent.md、capabilities.md、setup.md） | https://cursor.com/docs/cloud-agent/capabilities.md |
| macOS だけにする項目 | 無い | 本文を探したが記述なし（mcp.md） | — |

## 問い3: MobileBuildMCP と Xcode の MCP

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 改名で変わったもの | 2.7.1 で npm のパッケージ、コマンド（`mobilebuildmcp`、`mobilebuildmcp-doctor`）、Homebrew の formula、`MOBILEBUILDMCP_*` の環境変数、`.mobilebuildmcp/config.yaml`、`~/Library/Developer/MobileBuildMCP` が新しい名前になった。文書は getsentry/xcodebuildmcp.com リポジトリの原稿を指す | 本文で確認 | https://github.com/getsentry/XcodeBuildMCP/blob/main/CHANGELOG.md |
| 勧める起動のしかた | README: "Most clients can also run the MCP server on demand via `npx -y mobilebuildmcp@latest mcp` without a global install." `mobilebuildmcp setup` が出す設定も `{"command": "npx", "args": ["-y", "mobilebuildmcp@latest", "mcp"], "env": {…}}` | 本文で確認（README）、ソースで確認（src/cli/commands/setup.ts） | https://github.com/getsentry/XcodeBuildMCP |
| ツールごとの設定例 | 文書サイトの原稿（clients.mdx、最終更新 2026-07-10）は旧名のまま。Claude Code: `claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp`。Cursor: プロジェクトの `.cursor/mcp.json` を勧める（"Project-scoped (recommended)"）。Codex: `codex mcp add XcodeBuildMCP -- …` か `[mcp_servers.XcodeBuildMCP]`、道具が時間切れになるなら `tool_timeout_sec = 600`。新しい名前に読み替えると `npx -y mobilebuildmcp@<版> mcp` | 本文で確認（読み替えは本文からの読み取り） | https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/clients.mdx |
| Sentry への送信を止める | 環境変数 `MOBILEBUILDMCP_SENTRY_DISABLED=true`（`SENTRY_DISABLED=true` でも止まる）、または設定ファイルの `sentryDisabled: true`。旧名の `XCODEBUILDMCP_SENTRY_DISABLED` は 2.7.1 のソースのどこでも読まれていない。文書サイトの privacy.mdx はまだ旧名で、clients.mdx の例は `XCODEBUILDMCP_SENTRY_DISABLED=false` になっている | ソースで確認（src/utils/sentry-config.ts、src/utils/config-store.ts）、文書の状態は本文で確認 | 同上、https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/privacy.mdx |
| 何が送られるか | MobileBuildMCP 自身の実行時の失敗だけ。ビルドやテストの失敗、道具の入出力、環境変数、ソースは送らない、と書いている | 本文で確認 | privacy.mdx |
| 設定ファイルの場所 | サーバーのプロセスの作業ディレクトリの `.mobilebuildmcp/config.yaml`。親のディレクトリは探さない。`MOBILEBUILDMCP_CWD` で作業ディレクトリを変えられる | ソースで確認（src/utils/project-config.ts、src/runtime/bootstrap-runtime.ts） | https://github.com/getsentry/XcodeBuildMCP |
| 設定ファイルに書けるもの | `schemaVersion: 1`、`enabledWorkflows`（道具のまとまりを選ぶ）、`customWorkflows`（道具を名指しで束ねる）、`sessionDefaults`（`projectPath`・`workspacePath`、`scheme`、`configuration`、`simulatorName`・`simulatorId`、`platform`、`bundleId` など）、`sentryDisabled`、`debug`、`incrementalBuildsEnabled` など。`enabledWorkflows` の既定は `["simulator"]`。相対パスは作業ディレクトリから解く | 本文で確認（config.example.yaml、configuration.mdx）、パスの解き方はソースで確認 | config.example.yaml、https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/configuration.mdx |
| 道具のまとまり（workflows） | coverage、debugging、device、doctor、macos、project-discovery、project-scaffolding、session-management、simulator-management、simulator、swift-package、ui-automation、utilities、workflow-discovery、xcode-ide | ソースで確認（manifests/workflows/） | https://github.com/getsentry/XcodeBuildMCP |
| 優先順位 | 高い順に、道具の呼び出し（`session_set_defaults`）、設定ファイル、環境変数（"This follows the `git config` pattern"） | 本文で確認 | configuration.mdx |
| 設定ファイルの `sentryDisabled` の注意 | MCP の起動時、Sentry の初期化の前に設定ファイルを読むが、そのとき使うのは起動した時点の作業ディレクトリで、`MOBILEBUILDMCP_CWD` による移動はその後に行う。起動したディレクトリに `.mobilebuildmcp/` が無いと、設定ファイルの `sentryDisabled` は Sentry の初期化に効かない | ソースで確認（src/server/start-mcp-server.ts の順序） | 同上 |
| Linux で起動するとどうなるか | `package.json` に `os` の制限が無く、起動時に OS を確かめる処理も見当たらない。Linux でもサーバーは起動し、道具を呼ぶと `xcodebuild` などが無くて失敗すると読める | ソースからの読み取り（package.json、src の `process.platform` の検索） | 同上 |
| 版を固定するか | 公式の例はすべて `@latest`。ただし 2.7.0 で構造化出力の版と既定の構成が変わり（Breaking）、2.7.1 で名前と環境変数が変わった。`@latest` は起動のたびに新しい版を取りに行くので、`mobilebuildmcp@2.7.1` と書いて上げるときに確かめる方が、ツールの間で動きがそろう | 前半は本文で確認（CHANGELOG）、固定の勧めは本文からの読み取り | CHANGELOG.md |
| Xcode の MCP を中継する | `enabledWorkflows` に `xcode-ide` を入れると、`xcrun mcpbridge` を中継する `xcode_ide_list_tools`・`xcode_ide_call_tool` が出る。Xcode 26.3 以降と、Xcode の起動が要る | 本文で確認 | https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/xcode-ide.mdx |
| Xcode の MCP の設定（Apple） | Xcode の設定 > Intelligence で「Allow external agents to use Xcode tools」を入れる。Claude Code: `claude mcp add --transport stdio xcode -- xcrun mcpbridge`、Codex: `codex mcp add xcode -- xcrun mcpbridge`。"Before prompting an external agent (outside of Xcode), be sure to open your project in Xcode." | 本文で確認 | https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode |
| Xcode の MCP の設定（Cursor） | `~/.cursor/mcp.json` に `{"mcpServers": {"xcode-tools": {"command": "xcrun", "args": ["mcpbridge"]}}}`、CLI は `agent mcp add xcode-tools -- xcrun mcpbridge`。Xcode を起動してプロジェクトを開いておく | 本文で確認 | https://cursor.com/docs/integrations/xcode.md |

## 問い4: 下のディレクトリの AGENTS.md

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Claude Code は `AGENTS.md` を読むか | 読む。"Claude Code can read `AGENTS.md` as your project instructions, so a repository already set up for other coding agents works without adding a `CLAUDE.md`, an import, or a setting." v2.1.277 以降。既定では、作業ディレクトリかその上に `CLAUDE.md`・`.claude/CLAUDE.md`・`CLAUDE.local.md` が無いときだけ `AGENTS.md` を読む | 本文で確認 | https://code.claude.com/docs/en/memory.md |
| Claude Code は下のディレクトリの `AGENTS.md` を読むか | 読む。起動時は作業ディレクトリとその上の `AGENTS.md`。"As Claude works in subdirectories: a subdirectory's `AGENTS.md`, when Claude opens a file there with the Read tool and that subdirectory has none of the three `CLAUDE.md` files of its own" | 本文で確認 | 同上 |
| Claude Code で読まれないとき | v2.1.277 より前、組み込みの `agents-md` プラグインを切ったとき、上げた直後の最初のセッション。v2.1.281 より前は、Bedrock やテレメトリを切ったセッションでも読まない。`CLAUDE.local.md` を置くと、それが数えられて `AGENTS.md` を読まなくなる | 本文で確認 | 同上 |
| `CLAUDE.md` のシンボリックリンクは要るか | 要らない。以前の回避策（`@AGENTS.md` の import、シンボリックリンク）は残しても二重には読まない | 本文で確認 | 同上 |
| Codex | 起動時に1回、プロジェクトのルートから今のディレクトリまで、各ディレクトリで `AGENTS.override.md`、`AGENTS.md` の順に1つ読み、ルートから順につなぐ。"Codex stops searching once it reaches your current directory"。ルートで起動すると `ios/AGENTS.md` は読まない | 本文で確認 | https://learn.chatgpt.com/docs/agent-configuration/agents-md.md |
| Codex の大きさの上限 | `project_doc_max_bytes`（既定 32 KiB）。agents-md.md は「合わせた大きさ」（"once the combined size reaches the limit"）、config-advanced.md は「各ファイルから読む量」（"how much to read from each `AGENTS.md` file"）と書き、食い違っている。ルートと `ios/` で 26,280 バイト、ルートと `server/` で 30,746 バイトで、合わせた大きさで数えても今は収まる | 本文で確認（食い違いも）、計算は観察 | agents-md.md、https://learn.chatgpt.com/docs/config-file/config-advanced.md |
| Codex cloud と code review | cloud: "If your repo includes `AGENTS.md`, the agent uses it to find project-specific lint and test commands." code review: 変えたファイルごとに、ルートとより近い `AGENTS.md` の `## Code Review Rules` を当てる | 本文で確認 | https://learn.chatgpt.com/docs/environments/cloud-environment.md 、https://learn.chatgpt.com/docs/third-party/github.md |
| Cursor（エディタ） | "You can place `AGENTS.md` files in any subdirectory of your project, and they will be automatically applied when working with files in that directory or its children." 親の指示とつなぎ、近い方を優先する | 本文で確認 | https://cursor.com/docs/rules.md |
| Cursor（CLI、Cloud Agents） | CLI は「プロジェクトのルートの `AGENTS.md` と `CLAUDE.md`」を読む（下のディレクトリは書いていない）。Cloud Agents は "Cloud agents read `AGENTS.md` files." | 本文で確認（CLI の下のディレクトリは本文を探したが記述なし） | https://cursor.com/docs/cli/using.md 、https://cursor.com/docs/cloud-agent/setup.md |

## 問い5: PR の作成を共同作業者に絞った設定、interaction limits、locked の会話と bot

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| PR の作成を絞る設定 | 設定 > General > Features の「Pull requests」で「Collaborators only」。個人のリポジトリでは招待した人、組織では write・maintain・admin の役割の人が共同作業者。changelog: "All pull requests can be seen and commented on, but only collaborators (i.e., users with write access) can create new ones." REST API の `pull_request_creation_policy`（`all`・`collaborators_only`） | 本文で確認 | https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/disabling-pull-requests 、https://github.blog/changelog/2026-02-13-new-repository-settings-for-configuring-pull-request-access/ 、REST API の repos の説明 |
| この設定で GitHub App、Dependabot、Renovate、Codex、Cursor が PR を作れるか | GitHub の文書と changelog は「ユーザー」について書くだけで、GitHub App や bot を書いていない。Dependabot、Renovate、Codex、Cursor の文書にも、この設定との関係は書かれていない | 本文を探したが記述なし（上の文書、github/docs の content/code-security・content/apps・content/communities、Renovate の docs/usage、Codex の llms-full.txt、Cursor の github.md・cloud-agent 以下） | — |
| interaction limits | 一時的（24時間〜6か月）。「Limit to repository collaborators」は「書き込み権限の無いユーザー」の、コメント、Issue の作成、PR の作成、リアクション、編集を止める。bot や GitHub App の扱いは書いていない | 前半は本文で確認、bot は本文を探したが記述なし | https://docs.github.com/en/communities/moderating-comments-and-conversations/limiting-interactions-in-your-repository |
| locked の会話 | "While a conversation is locked, only people with write access and repository owners and collaborators can add, hide, and delete comments." ロックの API は「push できるユーザー」が使える。GitHub App のコメントの扱いは書いていない | 前半は本文で確認、App は本文を探したが記述なし（REST API の issues の説明を含む） | https://docs.github.com/en/communities/moderating-comments-and-conversations/locking-conversations |
| 各ツールは誰として PR を作るか | Claude Code on the web: GitHub のプロキシが「あなたの本物のトークン」に差し替え、PR のコメントの返信も「あなたの GitHub アカウント」で出す。Cursor: GitHub App に read-write を与え、App の権限に「Pull requests: Create PRs and leave review comments」。Bugbot は「自分が作った PR だけ」で動く。Codex: cloud の結果から PR を開ける、`@codex` のコメントで cloud のタスクが始まり「権限があれば」同じブランチに push する、とだけ書く。Renovate（Mend の App）: Pull Requests と Issues の write、ワークフローを直すには Workflows の write が要る | 本文で確認（誰の名前で作るかは Claude Code 以外は書かれていない） | https://code.claude.com/docs/en/cloud-environments.md 、https://code.claude.com/docs/en/claude-code-on-the-web.md 、https://cursor.com/docs/integrations/github.md 、https://cursor.com/docs/bugbot.md 、https://learn.chatgpt.com/docs/third-party/github.md 、https://github.com/renovatebot/renovate/blob/main/docs/usage/security-and-permissions.md |
| このリポジトリのロックのワークフローは Dependabot の PR でも動くか | Dependabot が起こした `pull_request` のワークフローでは `GITHUB_TOKEN` が既定で読み取りだけになるが、GitHub の例はワークフローに `permissions: pull-requests: write` を書いて Dependabot の PR に書き込んでいる。`lock-conversations.yml` は `issues: write`・`pull-requests: write` を書いているので、ロックできると読める | 前半は本文で確認、当てはめは本文からの読み取り | https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-on-actions 、https://docs.github.com/en/code-security/tutorials/secure-your-dependencies/automate-dependabot-with-actions |

## 問い6: Codex cloud と Cursor の Cloud Agents で Swift 6.4

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Codex cloud の既定の image | `universal`。openai/codex-universal は「参照用で、同一ではない」（"This is not an identical environment"）。最後のコミットは 2026-05-02 | 本文で確認 | https://learn.chatgpt.com/docs/environments/cloud-environment.md 、https://github.com/openai/codex-universal |
| 入っている Swift | swiftly で 6.2、6.1、5.10 を入れ、6.2 を使う。arm64 の image は Swift を入れない（実際に動かすのは amd64） | 本文で確認（README、Dockerfile の `ARG SWIFT_VERSIONS="6.2 6.1 5.10"`） | 同上 |
| `CODEX_ENV_SWIFT_VERSION` で 6.4 を選べるか | 選べない。対応は `5.10`、`6.1`、`6.2`。setup の処理は `swiftly use` で入っている版に切り替えるだけ | 本文で確認（README）、ソースで確認（setup_universal.sh） | 同上 |
| 6.4 を入れる道 | setup script で `swiftly install 6.4.0` などを走らせる。setup script はネットの接続があり（"Setup scripts run with internet access"）、コンテナは最大 12 時間キャッシュされる。エージェントの段階のネットは既定で切れている | 前半は本文からの読み取り（swiftly が入っていることと setup script の記述から）、後半は本文で確認 | cloud-environment.md、https://learn.chatgpt.com/docs/cloud/internet-access.md |
| Cursor の Cloud Agents の環境 | Ubuntu。`.cursor/environment.json` に `install`（Build のときに走る。冪等にする）、`start`、`terminals`、Dockerfile（`"build": {"dockerfile": …}`）を書ける。環境はリポジトリの `.cursor/environment.json`、個人の環境、チームの環境の順に決まる。エージェントは既定でネットにつながる | 本文で確認 | https://cursor.com/docs/cloud-agent/setup.md 、https://cursor.com/docs/cloud-agent/security-network.md |
| Cursor で 6.4 を入れる道 | Dockerfile で Swift の公式イメージを土台にするか、`install` で swiftly を入れて 6.4.0 を入れる | 本文からの読み取り（上の記述から。Swift を例にした記述は無い） | 同上 |

## 問い7: Claude Code on the web の Auto-fix

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 自分で作っていない PR を見張れるか | 見張れる。"Any existing PR: paste the PR URL into a session and tell Claude to auto-fix it"。CLI からは PR のブランチを checkout して `/autofix-pr` | 本文で確認 | https://code.claude.com/docs/en/claude-code-on-the-web.md 、https://code.claude.com/docs/en/commands.md |
| 要るもの | "Auto-fix requires the Claude GitHub App to be installed on your repository." | 本文で確認 | claude-code-on-the-web.md |
| 何に反応するか | CI の失敗とレビューのコメント。明らかな直しは push し、あいまいなものは人に聞く。ベースが進んで衝突しても GitHub は webhook を出さないので、反応しない | 本文で確認 | 同上 |
| push できる先 | "`git push` works only against the session's current working branch"。他の人の PR を直すには、セッションがその PR のブランチで作業している必要がある。fork からの PR のブランチには push できないと読める | 前半は本文で確認、後半は本文からの読み取り | https://code.claude.com/docs/en/cloud-environments.md |
| Dependabot の PR に commit を足すと | "By default, Dependabot will stop rebasing a pull request once extra commits have been pushed to it." commit のメッセージに `[dependabot skip]` などを入れれば、Dependabot が上書きしてよいことになる | 本文で確認 | https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/manage-your-dependency-security/manage-dependabot-prs |
| 他のツールの似た仕組み（参考） | Codex: PR に `@codex fix the CI failures` と書くと cloud のタスクが始まる。Cursor: 組み込みの `/autopilot`（PR を見張り、失敗したチェックなどに対応する）と、Cloud Agents の購読（"open a PR and keep CI green"） | 本文で確認 | https://learn.chatgpt.com/docs/third-party/github.md 、https://cursor.com/docs/skills.md 、https://cursor.com/docs/cloud-agent/capabilities.md |

## 問い8: Dependabot と Renovate

### Dependabot

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift の対応 | `package-ecosystem: swift`（v5、v6）。版の更新と安全性の更新。非公開の置き場は git だけ。宣言的でない manifest は扱わない | 本文で確認 | https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories |
| ローカルのパッケージ（`ios/NuToriCore/Package.swift`） | `Package.swift` があるディレクトリでは、`Package.swift` と `Package.resolved` を読み、`swift package show-dependencies` や `swift package resolve` を実行する。Dependabot の Swift の image は Swift 6.3.1 なので、`// swift-tools-version: 6.4` の manifest は読めずに失敗するおそれがある。NuToriCore には外の依存も `Package.resolved` も無いので、今は更新するものが無い | ソースで確認（swift/lib の file_fetcher.rb、dependency_parser.rb、swift/Dockerfile の `ARG SWIFT_VERSION=6.3.1`）、失敗のおそれは本文からの読み取り | https://github.com/dependabot/dependabot-core/tree/main/swift |
| Xcode のプロジェクトの依存（`project.pbxproj`、`project.xcworkspace/xcshareddata/swiftpm/Package.resolved`） | ソースは扱う。ディレクトリに `Package.swift` が無く、`.xcodeproj/`・`.xcworkspace/` の下に `Package.resolved` があると「Xcode のモード」になり、`project.pbxproj` の `exactVersion` の `version` などと `Package.resolved` を直す。GitHub の文書にはこの対応の記述が無い。今の nu-tori の Xcode のプロジェクトにはパッケージの依存も `Package.resolved` も無い | ソースで確認（xcode_file_helpers.rb、file_fetcher.rb、pbxproj_updater.rb）、文書は本文を探したが記述なし | 同上 |
| SHA で固定した `uses:` と版のコメント | 更新する。"Dependabot updates the version documentation of GitHub Actions when the comment is on the same line, such as `actions/checkout@<commit> #<tag or link>`"。`docker://` の参照は扱わない | 本文で確認 | https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories （GitHub Actions の注意書き） |
| ワークフローの `container:` のイメージ | `github-actions` は `uses:` だけを読む。`docker` のエコシステムは Dockerfile、Containerfile、Kubernetes・Helm の YAML を読み、YAML の中の `image:` の鍵を探す。`container: swift:…` のような文字列の書き方は拾わない。`container: {image: …}` と書き、`docker` の `directory` を `/.github/workflows` にすれば拾う可能性はあるが、文書に無い使い方 | ソースで確認（github_actions の file_parser.rb、docker の file_parser.rb）、最後は本文からの読み取り | https://github.com/dependabot/dependabot-core 、GitHub の Docker の節 |
| npm・pnpm（`server/`） | 対応する。`package-ecosystem: npm` で npm（v7〜v11）、pnpm（v7〜v10）、yarn | 本文で確認 | supported-ecosystems-and-repositories |

### Renovate

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift | `swift` の manager は `Package.swift` だけを対象にする（`managerFilePatterns` は、パスの最後が `Package.swift` のファイル）。更新したときは、リポジトリの中のすべての `Package.resolved` の該当する pin を書き換える（swift のコマンドは使わない）。`.exact()`・`exact:` 以外は範囲として扱う | 本文で確認（manager の readme）、対象のファイルと書き換えはソースで確認（lib/modules/manager/swift/index.ts、artifacts.ts） | https://github.com/renovatebot/renovate/tree/main/lib/modules/manager/swift |
| Xcode のプロジェクトの依存（`project.pbxproj`） | 対応する manager は無い | 本文を探したが記述なし（docs/usage、manager の一覧） | — |
| SHA で固定した `uses:` | "Renovate will update the commit SHA according to the GitHub tag you specified."（`# v4.0.0` のようなコメント）。コメントの無い SHA は既定で更新しない | 本文で確認 | https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/github-actions/readme.md |
| ワークフローの `container:` と `services:` | `github-actions` の manager がジョブの `container` と `services` を Docker の依存として取り出す（depType `container`）。Docker の digest は tag を残したまま更新し、`-noble` のような接尾辞は変えない | ソースで確認（extract.ts）、digest と接尾辞は本文で確認 | 同上、https://github.com/renovatebot/renovate/blob/main/docs/usage/docker.md |
| シェルスクリプトの版と SHA-256 の組 | 正規表現の custom manager で `currentValue` と `currentDigest` を名前つきで取り出せる。`github-release-attachments` の datasource は、今の版の配布物から `currentDigest` に合うものを探し、新しい版の同じ名前の配布物の digest を計算する | 前半は本文で確認（custom の regex の readme）、datasource はソースで確認（lib/modules/datasource/github-release-attachments/index.ts） | https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/custom/regex/readme.md |
| `scripts/check` の SwiftLint にそのまま当てられるか | 版は1か所（`swiftlint_version=0.65.1`）、SHA-256 は配布物ごとに3つあり、版と離れている。1つの一致で版と digest を組にする形なので、3つの SHA-256 のそれぞれの行に版を並べるなど、書き方を変える必要がある | 本文からの読み取り（上の2行と `scripts/check` の形から） | — |
| npm・pnpm | "`npm`, `yarn`, `pnpm` and `bun` are all supported." | 本文で確認 | https://github.com/renovatebot/renovate/blob/main/docs/usage/javascript.md |
| GitHub App が要るか、公開リポジトリで無料か | Mend が動かす Mend Renovate App を入れるか、自分で動かす（npm の CLI、Docker、GitHub Action の `renovatebot/github-action`）。Mend Renovate Community Cloud は "A generous free tier, available for all across an unlimited number of public and private repositories." OSI の承認したライセンスなら Community (OSS) の枠を申し込める | 本文で確認 | https://github.com/renovatebot/renovate/blob/main/docs/usage/mend-hosted/overview.md 、https://github.com/renovatebot/renovate/blob/main/docs/usage/getting-started/running.md |
| App が作るもの | Dependency Dashboard などの Issue（Issues の write）。Mend の App の Renovate は OSS 版より数時間〜1週間遅れる | 本文で確認 | security-and-permissions.md、https://github.com/renovatebot/renovate/blob/main/docs/usage/mend-hosted/hosted-apps-config.md |

## 問い9: Claude Code on the web の環境と swiftly

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| setup script | 環境の設定の「Setup script」に書く Bash。Claude Code の起動の前に、Ubuntu 24.04 の root で走る。0 以外で終わるとセッションが始まらない（失敗してよいコマンドには `\|\| true` を付けるよう勧めている）。およそ5分以内に終われば、ファイルシステムを snapshot して次から使う。script か許可ドメインを変えたとき、およそ7日で作り直す | 本文で確認 | https://code.claude.com/docs/en/cloud-environments.md |
| setup script と SessionStart hook の使い分け | setup script は VM に道具を入れる（クラウドだけ、キャッシュされる）。SessionStart hook はクラウドとローカルの両方で毎回走る（`CLAUDE_CODE_REMOTE` で分ける） | 本文で確認 | 同上 |
| ネットの接続の段階 | None、Trusted（既定。パッケージの置き場、GitHub など）、Full（すべて）、Custom（自分のリスト。既定のリストを含めるかを選べる。`*.` で下位のドメインすべて） | 本文で確認 | 同上 |
| `download.swift.org` を足せるか | Custom で足せる（任意のドメインを1行ずつ書く）。Trusted の既定のリストにあるのは `swift.org` と `www.swift.org` で、下位のドメインを含む印（`*`）は付いていない | 本文で確認。「Trusted のままでは `download.swift.org` に届かない」は本文からの読み取り | 同上（Default allowed domains） |
| 入っている道具 | Python、Node.js、Ruby、PHP、Java、Go、Rust、C/C++、Docker、PostgreSQL、Redis など。Swift は表に無い | 本文で確認 | 同上（Installed tools） |
| swiftly は下のディレクトリの `.swift-version` を読むか | 読まない。"Swiftly uses the `.swift-version` file, if present in your working directory (or parent)"。ソースも作業ディレクトリから親へ上がるだけ。ルートで `swift test --package-path ios/NuToriCore` を動かすと、`ios/.swift-version` ではなく全体の既定の版を使う | 本文とソースで確認（Documentation/SwiftlyDocs.docc/use-toolchains.md、Sources/Swiftly/Use.swift）、当てはめは本文からの読み取り | https://github.com/swiftlang/swiftly |
| swiftly で `.swift-version` の版を入れる | `.swift-version` のあるディレクトリで `swiftly install`（引数なし）。全体の既定は `swiftly use --global-default <版>` | 本文で確認 | 同上（swiftly-cli-reference.md） |

## nu-tori への当てはめ

ここは、上の表からの読み取り。決めるのは開発者で、決めたことはストック（`AGENTS.md` など）に書く。

1. **スキル**: 今の形（正本は `.agents/skills/`、Claude Code 向けに `.claude/skills/` からシンボリックリンク）は、Claude Code と Codex にはそのまま効く。Cursor は同じスキルを2か所から読むので、一覧に二重に出るかを Cursor で一度見る。`model-based-ui-design` は `.claude/skills/` にしか無いので、Codex でも使うなら置き場を考える（`.agents/skills/` は `skills update` で上書きされる決まりとの関係を先に確かめる）。
2. **AGENTS.md**: `CLAUDE.md` は足さない（Claude Code 2.1.277 以降は `AGENTS.md` を読む）。自分用の `CLAUDE.local.md` も置かない（置くと `AGENTS.md` が読まれなくなる）。Codex はルートで起動すると `ios/AGENTS.md` を読まないので、ルートの `AGENTS.md` の「そのディレクトリの `AGENTS.md` を読む」という引き金が効いている。Claude Code も「Read で開いたとき」なので、同じ引き金が要る。
3. **MCP**:
   - Xcode の MCP（`xcrun mcpbridge`）は、Xcode を開いておく必要があり、Linux では起動しない。リポジトリの設定に入れず、Mac の上で各ツールの利用者の設定（`claude mcp add --scope user`、`~/.codex/config.toml`、`~/.cursor/mcp.json`）に足すのが、クラウドに「失敗したサーバー」を出さない形。
   - MobileBuildMCP は、リポジトリに置くなら `.mcp.json`（Claude Code）、`.cursor/mcp.json`（Cursor）、`.codex/config.toml`（Codex、信頼が要る）の3つに、同じ内容を書くことになる。版は `mobilebuildmcp@2.7.1` のように固定し、`env` に `MOBILEBUILDMCP_SENTRY_DISABLED=true` を書く（設定ファイルの `sentryDisabled` は、起動したディレクトリによっては効かない）。`.mobilebuildmcp/config.yaml` をルートに置き、`sessionDefaults` に `projectPath: ./ios/NuTori.xcodeproj` と `scheme: NuTori` を書けば、エージェントがプロジェクトを探す手間が減る。クラウド（Linux）では MobileBuildMCP も起動はするが、道具はどれも失敗する。
4. **PR の作成を共同作業者に絞った設定とロック**: bot がどう扱われるかは、どの文書にも無い。Dependabot か Renovate を入れるとき、Codex や Cursor に PR を作らせるときに、テストの PR を1つ作らせて、作れるか、ロックの後にコメントできるか（Codex のレビュー、Bugbot、Renovate の PR 本文の更新）を確かめる。作れなければ、その bot のための設定（`all` に戻す、ロックのワークフローから bot を外す）を選ぶ。
5. **依存の更新**: 今のリポジトリで更新したいものは、`uses:` の SHA、`container:` の Swift のイメージの digest、`scripts/check` の SwiftLint の版と SHA-256。Swift のパッケージの依存はまだ無い。
   - Dependabot の `github-actions` だけなら、GitHub の設定だけで `uses:` は追えるが、`container:` と SwiftLint は追えない。
   - Renovate なら3つとも追える。ただし Mend の App を入れる（またはワークフローで自分で動かす）ことと、SwiftLint の SHA-256 の書き方を変えることが要る。
   - Swift のパッケージの依存を足したら、Dependabot は Swift 6.3.1 で manifest を読むので、`swift-tools-version: 6.4` を読めるかを確かめる必要がある。Renovate は swift のコマンドを使わない。
6. **クラウドの Swift 6.4**: Claude Code on the web は、setup script で swiftly を入れ、`swiftly install --use 6.4.0` などで全体の既定を 6.4 にする。`ios/.swift-version` はルートで動かす `scripts/check` には効かない。ネットは Custom で `download.swift.org` を足す。Codex cloud と Cursor の Cloud Agents も setup script・`install` で同じことをする。

## 出典一覧

Anthropic（Markdown 版を取得。2026-09-26）
- Skills: https://code.claude.com/docs/en/skills.md
- Memory（CLAUDE.md と AGENTS.md）: https://code.claude.com/docs/en/memory.md
- MCP: https://code.claude.com/docs/en/mcp.md
- Settings reference: https://code.claude.com/docs/en/settings-reference.md
- Use Claude Code in the cloud（Auto-fix）: https://code.claude.com/docs/en/claude-code-on-the-web.md
- Configure cloud environments: https://code.claude.com/docs/en/cloud-environments.md
- Commands（`/autofix-pr`）: https://code.claude.com/docs/en/commands.md
- Web quickstart: https://code.claude.com/docs/en/web-quickstart.md
- Changelog: https://code.claude.com/docs/en/changelog.md

OpenAI（Markdown 版を取得。2026-09-26）
- Build skills: https://learn.chatgpt.com/docs/build-skills.md
- Custom instructions with AGENTS.md: https://learn.chatgpt.com/docs/agent-configuration/agents-md.md
- Model Context Protocol: https://learn.chatgpt.com/docs/extend/mcp.md
- Config basics: https://learn.chatgpt.com/docs/config-file/config-basic.md 、Advanced: https://learn.chatgpt.com/docs/config-file/config-advanced.md 、Reference: https://learn.chatgpt.com/docs/config-file/config-reference.md
- Codex cloud: https://learn.chatgpt.com/docs/cloud.md 、Cloud environments: https://learn.chatgpt.com/docs/environments/cloud-environment.md 、Agent internet access: https://learn.chatgpt.com/docs/cloud/internet-access.md
- Review GitHub pull requests with Codex: https://learn.chatgpt.com/docs/third-party/github.md
- openai/codex-universal（47f4f0e、2026-05-02）: https://github.com/openai/codex-universal

Cursor（Markdown 版を取得。2026-09-26）
- Skills: https://cursor.com/docs/skills.md
- Rules（AGENTS.md）: https://cursor.com/docs/rules.md
- MCP: https://cursor.com/docs/mcp.md 、CLI の MCP: https://cursor.com/docs/cli/mcp.md 、CLI の使い方: https://cursor.com/docs/cli/using.md
- Cloud Agents: https://cursor.com/docs/cloud-agent.md 、setup: https://cursor.com/docs/cloud-agent/setup.md 、capabilities: https://cursor.com/docs/cloud-agent/capabilities.md 、security and network: https://cursor.com/docs/cloud-agent/security-network.md
- Run modes（既定の許可ドメイン）: https://cursor.com/docs/agent/security/run-modes.md
- GitHub: https://cursor.com/docs/integrations/github.md 、Bugbot: https://cursor.com/docs/bugbot.md 、Xcode: https://cursor.com/docs/integrations/xcode.md

GitHub（github/docs の原稿 18945a3 と REST API の説明データ。2026-09-26）
- Disabling pull requests: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/disabling-pull-requests
- Limiting interactions in your repository: https://docs.github.com/en/communities/moderating-comments-and-conversations/limiting-interactions-in-your-repository
- Locking conversations: https://docs.github.com/en/communities/moderating-comments-and-conversations/locking-conversations
- Supported ecosystems and repositories（Dependabot）: https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories
- Keeping your actions up to date with Dependabot: https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/auto-update-actions
- Dependabot on Actions: https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-on-actions
- Automating Dependabot with GitHub Actions: https://docs.github.com/en/code-security/tutorials/secure-your-dependencies/automate-dependabot-with-actions
- Managing Dependabot pull requests: https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/manage-your-dependency-security/manage-dependabot-prs
- changelog: https://github.blog/changelog/2026-02-13-new-repository-settings-for-configuring-pull-request-access/ 、https://github.blog/changelog/2026-06-29-restrict-issue-creation-to-collaborators-only/
- dependabot/dependabot-core（f3a79fa）: https://github.com/dependabot/dependabot-core

Apple
- Giving external agents access to Xcode: https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode

Renovate（renovatebot/renovate e02925f）
- Swift の manager: https://github.com/renovatebot/renovate/tree/main/lib/modules/manager/swift
- GitHub Actions の manager: https://github.com/renovatebot/renovate/tree/main/lib/modules/manager/github-actions
- Docker: https://github.com/renovatebot/renovate/blob/main/docs/usage/docker.md
- custom の regex manager: https://github.com/renovatebot/renovate/blob/main/lib/modules/manager/custom/regex/readme.md
- JavaScript: https://github.com/renovatebot/renovate/blob/main/docs/usage/javascript.md
- Mend-hosted: https://github.com/renovatebot/renovate/blob/main/docs/usage/mend-hosted/overview.md 、Running: https://github.com/renovatebot/renovate/blob/main/docs/usage/getting-started/running.md 、Security and permissions: https://github.com/renovatebot/renovate/blob/main/docs/usage/security-and-permissions.md

Swift
- swiftlang/swiftly（468a23e）: https://github.com/swiftlang/swiftly

第三者（準公式）
- getsentry/XcodeBuildMCP（MobileBuildMCP 2.7.1、d13ff0c）: https://github.com/getsentry/XcodeBuildMCP
- getsentry/xcodebuildmcp.com（文書の原稿、78e43ff）: https://github.com/getsentry/xcodebuildmcp.com
- npm: https://registry.npmjs.org/mobilebuildmcp
