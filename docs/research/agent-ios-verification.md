# AI コーディングエージェントに iOS アプリの検証を自律的に回させる仕組み（Claude Code・Codex・Cursor）

調査日: 2026-09-24
対象: nu-tori の初回リリース（iPhone のみ、Swift・SwiftUI）を、エージェントにビルド、テスト、シミュレータ操作、スクリーンショット確認、修正まで自律的に回させる方法。前提は `docs/research/swift-vs-react-native.md`（Swift で作る。ビルドと画面の確認には Mac と Xcode が要る）

> **確認の方法と限界**
> - Apple の開発者向けドキュメントとリリースノートは、同じ内容の JSON（`https://developer.apple.com/tutorials/data/<パス>.json`）を取得して**本文を直接読んだ**。出典にはふつうの URL を書く。Xcode Cloud の料金は HTML（developer.apple.com/xcode-cloud/）を読んだ。
> - Claude Code は code.claude.com/docs の Markdown 版（`.md`）と、週ごとの What's new、changelog を読んだ。Codex は developers.openai.com/codex/llms.txt から辿れる learn.chatgpt.com/docs の Markdown 版を読んだ（Codex の文書は ChatGPT の文書に統合されている）。Cursor は cursor.com/docs の Markdown 版を読んだ。
> - 公式リポジトリは clone して読んだ: openai/plugins（build-ios-apps プラグイン）、openai/codex-universal、getsentry/XcodeBuildMCP（2026-09-23 の v2.7.1 で MobileBuildMCP に改名）、anthropics/claude-code-action、actions/runner-images。GitHub Actions の料金は docs.github.com の本文 API で読んだ。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。本文を探しても記述が無かったものは「本文を探したが記述なし」と書き、探したページを添える。
> - 実機・Mac での動作確認はしていない（この調査は Linux のクラウド環境で行った）。二次情報（ブログ、記事、SNS）は使っていない。XcodeBuildMCP は Sentry が保守する第三者のツールだが、OpenAI の公式プラグインが採用しているので「準公式」として扱った。
> - 状況は非常に速く動いている。Xcode 27 は 2026-09-14 に出たばかりで、Claude Code Desktop のシミュレータ画面はまだ Xcode 27 に対応していない、Xcode の「開いたワークスペース不要の MCP」はプレビュー、など、2026-09-24 時点の状態を書いた。

## 結論の要約

- **3社とも「Mac の上で動かす形」なら iOS の検証をエージェントに回させられる。クラウドの管理された環境は3社とも Linux で、iOS のビルドとシミュレータは動かない**（本文で確認）。違いは「自分の Mac をクラウドのエージェントの実行先としてつなげるか」と「外出中にどう操作するか」。
- **Mac の上の検証の道具は、3社共通で2つある。**
  1. **Xcode の MCP（`xcrun mcpbridge`）**: Apple 公式。Claude Code と Codex の設定手順を Apple 自身が書いており、Cursor も公式に案内している。ビルド、テスト、ビルドログ、SwiftUI プレビューのスクリーンショット（RenderPreview）がある。Xcode 27 から、シミュレータの起動、アプリの起動、タッチ、スクリーンショット、デバッガ、クラッシュなどの情報も扱える（本文で確認）。ただし Xcode を起動してプロジェクトを開いておく必要があり、接続の許可ダイアログが出る。Xcode 27 の「開いたワークスペース不要・無人向け」の MCP はまだプレビュー（本文で確認）。
  2. **XcodeBuildMCP（2026-09-23 から MobileBuildMCP）**: Sentry が保守。シミュレータのビルド・起動・テスト、UI の要素の取得、タップ、スワイプ、文字入力、スクリーンショット、ログ、LLDB、実機へのビルド・インストール・テストがある。v2.7.0 で Xcode 27 の Device Hub に対応した。OpenAI の公式プラグイン「Build iOS Apps」がこれを組み込んでいる（本文で確認）。Xcode を開いておかなくても `xcodebuild` と `simctl` で動く（本文からの読み取り）。
- **ツールごとの特徴**（本文で確認）
  - **Claude Code**: Desktop（Mac）に iOS シミュレータの画面（パブリックベータ）があり、Claude が画面を見ながらタップして確かめる。ただし **Xcode 27 ではまだ動かない**（Xcode 26.x を並べて入れて選ぶ）。CLI では computer use（Pro・Max のみ、対話モードのみ）でシミュレータを操作できる。外出中は Remote Control（全プラン）で Mac のセッションをスマホから操作できる。クラウドのセッションを自分の Mac で動かす self-hosted environments は **Team・Enterprise のみ**（Team は2人から）。
  - **Codex**: Xcode 26.3 から Xcode に組み込まれている。OpenAI 公式の「Build iOS Apps」プラグイン（XcodeBuildMCP を同梱）がある。ChatGPT デスクトップアプリの Computer Use は「iOS シミュレータの流れを試す」用途を挙げている。外出中は Remote で Mac をスマホから操作できる。Codex cloud は Ubuntu のコンテナで、自分の Mac を cloud の実行先にする仕組みは見当たらない。Codex の GitHub Action は macOS のランナーで動くと明記している。
  - **Cursor**: エディタのエージェントに Xcode の MCP をつなぐ公式手順がある。Cloud Agents は Ubuntu だが、**My Machines で自分の Mac を Cloud Agents の実行先にできる**（「iOS 開発用の Mac」を例に挙げている。Enterprise は不要で、個人の認証で始められる）。Mac の worker で computer use も使える。Automations は「CI が終わったとき」「GitHub Actions のワークフローが終わったとき」で起動できる。
- **Mac が寝ている・閉じているときは、Mac の上の仕組みはどれも止まる**（本文で確認: Claude Desktop のスケジュールは蓋を閉じると眠る、Codex Remote は蓋を閉じるなら外部ディスプレイが要る、Cursor の computer use はログインした画面が要る）。その間に回せるのは **CI（GitHub Actions の macOS ランナーか Xcode Cloud）＋クラウドのエージェント**だけ。GitHub Actions には Xcode 27 のイメージ（`xcode-27` ラベル、プレビュー）がある。
- **実機は、エージェントに自動で操作させる道が無い。** Claude Code のシミュレータ画面は「実機は操作できない」と明記。XcodeBuildMCP の UI 操作はシミュレータだけで、実機はビルド・インストール・起動・テストまで。HealthKit のバックグラウンド配信は「シミュレータでは試せない」（Apple）。実機では XCTest を `xcodebuild test` で回すところまでは自動にできるが、他アプリからの書き込みで起こされるかの確認は人が行う前提にする（本文からの読み取り）。
- **提案（この開発者の条件）**: 普段は **Mac の上の Claude Code（CLI）に XcodeBuildMCP と Xcode の MCP をつなぎ**、ビルド→テスト→シミュレータ操作→スクリーンショットを回させる。外出中で Mac が起きているときは **Remote Control（server mode）**でスマホから指示する。夜間や Mac を閉じているときは、**クラウドの Claude Code（Linux）でロジックと UI 以外を進め、PR の CI（GitHub Actions の macOS ランナー、XCUITest とスクリーンショット添付）を Auto-fix で直させる**。実機の確認は人が週に数回まとめて行う。詳細は末尾の「おすすめ」。

## 前提: 2026-09-24 時点の状態

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Xcode の最新 | Xcode 27（2026-09-14）。27.1・27.2 はベータ。Xcode 27 は macOS Tahoe 26.6 以降が要る | 本文で確認 | https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes 、`swift-vs-react-native.md` |
| Xcode 27 の大きな変更（検証に関係するもの） | Simulator アプリが Device Hub に置き換わった（Claude Code の文書: "Xcode 27, which replaces the Simulator app with Device Hub"）。iOS 27 以降の iPhone は Wi-Fi でペアリングできる | 本文で確認 | https://code.claude.com/docs/en/desktop-ios-simulator.md 、https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub |
| Claude Code の最新 | CLI 2.1.281（2026-09-23） | 本文で確認 | https://code.claude.com/docs/en/changelog.md |
| XcodeBuildMCP の最新 | v2.7.1（2026-09-23）で MobileBuildMCP に改名。npm は `mobilebuildmcp`。旧名の `xcodebuildmcp` は 2.7.0 で止まっている | 本文で確認（CHANGELOG、npm） | https://github.com/getsentry/XcodeBuildMCP |

## 問い1: Mac の上で動かす形

### 共通の道具: Xcode の MCP（`xcrun mcpbridge`）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 外部のエージェントから使えるか | Xcode 26.3 から。Xcode の設定 > Intelligence で「Allow external agents to use Xcode tools」を入れ、`claude mcp add --transport stdio xcode -- xcrun mcpbridge`、`codex mcp add xcode -- xcrun mcpbridge` で足す。「プロンプトの前にプロジェクトを Xcode で開いておく」（"be sure to open your project in Xcode"） | 本文で確認 | https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode |
| Xcode 26.3 の道具 | Cursor の文書が 20 個の道具を挙げている: ファイル操作、BuildProject、GetBuildLog、RunAllTests、RunSomeTests、GetTestList、Issue Navigator の警告とエラー、RenderPreview（SwiftUI プレビューのスクリーンショット）、DocumentationSearch、ExecuteSnippet など | 本文で確認 | https://cursor.com/docs/integrations/xcode.md |
| Xcode 27 で足されたもの | 「シミュレータを起動し、アプリを入れて起動し、タッチを送り、スクリーンショットで UI の振る舞いを確かめる」（"Agents can now boot simulators, install and launch apps, synthesize touch events, and capture screenshots to verify UI behavior."）。プレビューをライト・ダーク、向き、文字サイズ違いで描ける。デバッガの操作とコンソールの読み取り、スキーム、ビルド設定、entitlement、Info.plist。クラッシュ、ハング、起動の問題などの情報（"insights about your projects, such as crashes … hangs and launch issues"） | 本文で確認 | https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes |
| 権限の確認 | Xcode 26.3 で細かい権限の仕組みが入った。接続のときに「Allow Connection?」が何度も出る不具合があった（26.3 で修正）。Xcode 27 ではエージェントとその子プロセスのファイルアクセスを監視する層を有効にできる | 本文で確認 | https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes 、Xcode 27 リリースノート |
| 無人で回せるか | Xcode 27 Beta 5 から「開いた Xcode のワークスペースが無くても動く MCP サーバー」のプレビューがある（`sudo xcrun mcp-server enable`）。署名済みのエージェントに、ディレクトリ単位で長い期間の許可を与えられる。無人の環境向けに `--unsafe-always-allow-all-agents` もあるが「机の前で使うのは勧めない」。「早いプレビューなので、構成によっては動かず、Xcode の再起動や Mac の再起動が要ることがある」 | 本文で確認 | Xcode 27 リリースノート（181836944） |
| 実機 | Xcode 27 の文書が挙げる「エージェントが確かめる」機能はシミュレータ、watchOS、tvOS（Siri Remote）。iPhone 実機をエージェントが操作できるとは書かれていない | 本文を探したが記述なし（Xcode 27 リリースノート、Device Hub の文書） | 同上 |

### 共通の道具: XcodeBuildMCP（MobileBuildMCP）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 何か | 「iOS と macOS のプロジェクトでエージェントが使う道具を出す MCP サーバーと CLI」。MIT ライセンス。Sentry が保守。要件は macOS 14.5 以降、Xcode 16 以降、Node.js 18 以降（Homebrew なら不要）。Cursor、Claude Code、Codex の設定例がある | 本文で確認 | https://github.com/getsentry/XcodeBuildMCP （README） |
| 道具 | シミュレータ: build_sim、build_run_sim、test_sim、boot_sim、install・launch・stop、ダークモード、位置情報、ステータスバー、動画の録画。UI 操作: snapshot_ui（画面の要素）、tap、swipe、drag、long_press、gesture、type_text、key_press、screenshot。ログ: シミュレータのログの取得。デバッグ: LLDB。実機: build_device、build_run_device、test_device、install・launch。Xcode の MCP を中継する xcode_ide_call_tool もある | 本文で確認（manifests/tools、manifests/workflows） | 同上 |
| UI 操作は実機でもできるか | UI 操作の対象は「iOS シミュレータ」（"UI automation and accessibility testing tools for iOS simulators"）。実機のワークフローはビルド、テスト、インストール、起動まで | 本文で確認 | 同上（manifests/workflows/ui-automation.yaml、device.yaml） |
| Xcode 27 対応 | v2.7.0 で「Xcode 27 の Device Hub のシミュレータで UI 操作が完全に動く」。テスト結果は `.xcresult` で返し、ビルド済みのテストを再ビルドなしで回せる | 本文で確認 | 同上（CHANGELOG 2.7.0） |
| 注意 | 2026-09-23 に改名し、パッケージ名、環境変数、設定ディレクトリ（`.mobilebuildmcp/config.yaml`）が変わった。OpenAI のプラグインはまだ `xcodebuildmcp@latest`（2.7.0）を指している。実行時エラーを Sentry に送る（オプトアウトできる） | 本文で確認 | 同上（CHANGELOG 2.7.1、README）、https://github.com/openai/plugins （plugins/build-ios-apps/.mcp.json） |

### Claude Code（CLI、デスクトップ）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| iOS 向けの公式の案内 | 「Test iOS apps in the simulator」のページがある。Claude Code Desktop（macOS）の iOS シミュレータの画面で、Claude がアプリを入れ、タップし、画面を読んで自分の変更を確かめる（"Claude installs the app, taps through it, and reads the screen to verify its own changes"）。パブリックベータ、Pro・Max・Team・Enterprise | 本文で確認 | https://code.claude.com/docs/en/desktop-ios-simulator.md |
| Xcode 27 で使えるか | **まだ使えない**（"The pane doesn't yet work with Xcode 27"）。Xcode 26.x を並べて入れ、`xcode-select` で選ぶよう案内している | 本文で確認 | 同上 |
| シミュレータ画面の権限 | 端末ごとに一度だけ許可すれば、タップ、入力、起動、スクリーンショットは確認なしで動く。ビルド（`xcodebuild` がビルドスクリプトを動かすため）と URL を開く操作は権限モードに従う。セッションごとに別のシミュレータを使い、1セッションで4台まで | 本文で確認 | 同上 |
| CLI からシミュレータを操作できるか | computer use（組み込みの MCP サーバー `computer-use`）で、マウスと同じようにシミュレータを操作する。例として「XCTest を書かずにシミュレータの流れを試す」を挙げている。**Pro・Max のみ（Team・Enterprise は不可）、macOS のみ、対話モードのみ（`-p` では使えない）**。同時に画面を使えるのは1セッション。macOS のアクセシビリティと画面収録の許可、アプリごとの承認が要る | 本文で確認 | https://code.claude.com/docs/en/computer-use.md |
| MCP で Xcode・XcodeBuildMCP を使えるか | Xcode の MCP は Apple が Claude Code 向けの手順を書いている。XcodeBuildMCP も Claude Code の設定例がある。computer use の文書も「MCP サーバーがあればそちらを先に使う」と書いている | 本文で確認 | Apple の文書、XcodeBuildMCP の README、computer-use.md |
| ビルド、XCTest・XCUITest、ログ、クラッシュ | Claude Code 自身に iOS 専用の道具は無い。Bash で `xcodebuild test`、`xcrun simctl`、`xcrun xcresulttool` を直接叩くか、上の MCP を使う | 本文からの読み取り（Claude Code の文書に iOS 専用の道具の記述が無いことと、MCP の案内から） | — |
| Xcode の中の Claude | Xcode 26.3 から Xcode の中で「Claude Agent」を使える（Xcode のコーディングアシスタント）。Xcode 27 では Apple 製のスペシャリストやプラグインも使える | 本文で確認 | Xcode 26.3・27 リリースノート、https://developer.apple.com/documentation/xcode/setting-up-coding-intelligence |

### Codex（CLI、ChatGPT デスクトップアプリ）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Xcode との統合 | Xcode 26.3 から Xcode の中で Codex を使える。外部の Codex CLI には `codex mcp add xcode -- xcrun mcpbridge` で Xcode の MCP を足す。Xcode 27 で「Apple 製のスキルが Codex で使えないことがある」不具合が直った | 本文で確認 | Apple の各文書 |
| iOS 向けの公式プラグイン | OpenAI の「Build iOS Apps」（v0.1.2）。スキル: ios-debugger-agent（XcodeBuildMCP でシミュレータのビルド、実行、UI 操作、ログ）、ios-simulator-browser（シミュレータを Codex のアプリ内ブラウザに映し、SwiftUI プレビューをホットリロード）、swiftui-liquid-glass、swiftui-performance-audit、ios-memgraph-leaks など。XcodeBuildMCP を `simulator,ui-automation,debugging,logging` で同梱 | 本文で確認 | https://github.com/openai/plugins （plugins/build-ios-apps） |
| Computer Use | ChatGPT デスクトップアプリ（macOS・Windows）のプラグイン。向いている用途に「ChatGPT が作っている macOS アプリ、Windows アプリ、iOS シミュレータの流れを試す」を挙げる。macOS では裏で動かせる。画面収録とアクセシビリティの許可、アプリごとの承認が要る | 本文で確認 | https://learn.chatgpt.com/docs/computer-use.md |
| iOS 向けの文書 | Codex の文書（Codex manual 全体）を探したが、iOS アプリの検証の手順を書いたページは無い。案内は上のプラグインと Apple の文書にある | 本文を探したが記述なし（https://learn.chatgpt.com/docs/codex-manual.md で iOS、Xcode、Simulator を検索） | — |

### Cursor（エディタのエージェント、CLI）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Xcode との統合 | 公式の「Xcode」ページがある。Xcode 26.3 以降の MCP を `xcrun mcpbridge` でつなぎ、ファイルの読み書き、ビルド、テスト、SwiftUI プレビューのキャプチャ、Apple の文書の検索ができる。Xcode を起動してプロジェクトを開いておく必要がある。有料プランが要る。Cursor CLI（`agent`）でも同じ設定を使える | 本文で確認 | https://cursor.com/docs/integrations/xcode.md |
| シミュレータの操作 | Cursor の文書に、エディタのエージェントがシミュレータをタップ・スクリーンショットする専用の仕組みは見当たらない。XcodeBuildMCP を MCP として足せば同じことができる（XcodeBuildMCP に Cursor の設定例がある） | 前半は本文を探したが記述なし（cursor.com/llms.txt の一覧、Xcode のページ）、後半は本文で確認 | XcodeBuildMCP の README |

## 問い2: クラウドで動かす形

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Claude Code on the web で macOS を選べるか | 選べない。「各セッションは Ubuntu 24.04、x86_64 の新しい VM」（"a fresh virtual machine (VM) running Ubuntu 24.04 on x86_64"）。4 vCPU、16 GB。ベースイメージの差し替えはまだできない | 本文で確認 | https://code.claude.com/docs/en/cloud-environments.md |
| Claude Code で自分の Mac をクラウドのセッションの実行先にできるか | self-hosted environments のランナーは Linux か macOS のホストで動く（"A Linux or macOS host"）。claude.ai、スマホ、routines から始めたクラウドのセッションが自分のマシンで動く。ただし **Team・Enterprise のパブリックベータで、既定は無効**。Team は2人から（claude.com/pricing: "For teams of 2 to 150"） | 本文で確認 | https://code.claude.com/docs/en/self-hosted-environments.md 、https://code.claude.com/docs/en/self-hosted-environments-quickstart.md 、https://claude.com/pricing |
| Claude Code の個人向けのつなぎ方 | 「常時起動の自分のマシンで Claude Code を動かし、他の端末から操作するなら Remote Control」（Pro・Max でも使える）。`claude remote-control` の server mode は、スマホの Claude アプリにマシンが「デバイス」として出て、そこから新しいセッションを始められる（2026-08 から）。`--spawn worktree` でセッションごとに worktree を分けられる。Dispatch（Pro・Max）は、スマホから頼んだ作業を Desktop の Code セッションとして始める | 本文で確認 | https://code.claude.com/docs/en/remote-control.md 、https://code.claude.com/docs/en/whats-new/2026-w34.md 、https://code.claude.com/docs/en/desktop.md |
| Remote Control でシミュレータ画面や computer use は使えるか | シミュレータ画面は「ローカルのセッションだけ」（クラウドや SSH のセッションでは使えない）。Remote Control は Mac の上のセッションそのものなので、Mac 側の MCP（XcodeBuildMCP など）はそのまま使える（"your filesystem, MCP servers, tools, and project configuration all stay available"）。Dispatch から始めた Desktop のセッションは computer use を使える（承認は30分で切れる） | 本文で確認 | desktop-ios-simulator.md、remote-control.md、desktop.md |
| Codex cloud で macOS を選べるか | 選べない。Codex cloud は `universal` というコンテナで動き、参照用の Dockerfile は `FROM ubuntu:24.04`（Linux の Swift 6.2 などは入っている） | 本文で確認 | https://learn.chatgpt.com/docs/environments/cloud-environment.md 、https://github.com/openai/codex-universal |
| Codex で自分の Mac をつなぐ仕組み | Codex Remote: ChatGPT デスクトップアプリ（macOS・Windows）の入ったマシンを、スマホの ChatGPT から操作する。タスクはつないだマシンで動き、そのマシンの MCP、スキル、Computer Use を使う。「常時起動の Mac」を置く使い方も案内している。**Codex cloud のタスクを自分の Mac で動かす仕組みは見当たらない** | 前半は本文で確認、後半は本文を探したが記述なし（cloud、cloud-environment、remote-connections、Codex manual で self-hosted を検索） | https://learn.chatgpt.com/docs/remote.md 、https://learn.chatgpt.com/docs/remote-connections.md |
| Cursor の Cloud Agents で macOS を選べるか | 管理された Cloud Agents は「隔離された Ubuntu のマシン」（"Cloud agents run on isolated Ubuntu machines"） | 本文で確認 | https://cursor.com/docs/cloud-agent/setup.md |
| Cursor で自分の Mac をつなぐ仕組み | **My Machines**: `agent worker start` で自分の Mac を worker にし、cursor.com/agents、デスクトップアプリ、iOS アプリから始めた Cloud Agent の道具の実行（ファイル編集、コマンド、computer use、ローカルの MCP）をその Mac で行う。Self-Hosted Machines の用途に「iOS 開発用の Mac」を挙げている（"Macs for iOS development"）。My Machines は個人の認証で始められ、Enterprise が要るのは Team Pools | 本文で確認 | https://cursor.com/docs/cloud-agent/self-hosted.md 、https://cursor.com/docs/cloud-agent/self-hosted/my-machines.md |
| Cursor の Mac worker で画面を操作できるか | `--computer-use` で worker の画面を操作できる。macOS では Cursor Computer Use のヘルパーにアクセシビリティと画面収録の許可が要り、「ログインした GUI のセッション」が要る。スクリーンショットや動画はアーティファクトとして PR やダッシュボードに出る | 本文で確認 | https://cursor.com/docs/cloud-agent/self-hosted/computer-use.md 、https://cursor.com/docs/cloud-agent/capabilities.md |

## 問い3: CI を介す形

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| GitHub Actions の macOS ランナーで Xcode 27 を使えるか | macOS 26（`macos-latest`、`macos-26`）の既定は Xcode 26.6。Xcode 27 は `xcode-27` ラベルのイメージがパブリックプレビュー（macOS 27、arm64） | 本文で確認 | https://github.com/actions/runner-images （README、images/macos/xcode-27-arm64-Readme.md） |
| GitHub Actions の費用 | 公開リポジトリの標準ランナーは無料。非公開リポジトリは無料枠（Free 2,000 分/月、Pro 3,000 分/月）を超えると macOS は 1 分 0.062 ドル（Linux は 0.006 ドル）。自分の Mac を self-hosted runner にすれば Actions の料金はかからない。macOS の分が無料枠をどう消費するかの倍率は、読んだページには書かれていなかった | 前半は本文で確認、倍率は本文を探したが記述なし | https://docs.github.com/en/billing/concepts/product-billing/github-actions 、https://docs.github.com/en/billing/reference/actions-runner-pricing |
| Xcode Cloud | Apple Developer Program に月 25 計算時間が含まれる。追加は 100 時間 49.99 ドル/月から。App Store Connect API でビルドを始め、成果物（「アプリのアーカイブ、テスト結果のバンドル、ビルドログ」）、問題、テスト結果を読める。Webhook と Slack 連携もある | 本文で確認 | https://developer.apple.com/xcode-cloud/ 、https://developer.apple.com/documentation/appstoreconnectapi/xcode-cloud-workflows-and-builds 、https://developer.apple.com/documentation/appstoreconnectapi/ciartifact |
| クラウドの Claude Code が CI の失敗を直せるか | Auto-fix: PR を見張り、CI の失敗やレビューコメントが来たら調べて直し、push する。Claude GitHub App が要る。クラウドのセッションには `gh` が入っている。CLI からは `/autofix-pr` で始められる | 本文で確認 | https://code.claude.com/docs/en/claude-code-on-the-web.md |
| クラウドの Claude Code が xcresult やスクリーンショットを読めるか | ログは `gh` で読める。ただし Actions の成果物（xcresult の zip）のダウンロード先は既定の許可ドメイン（github.com、objects.githubusercontent.com など）に無い可能性があり、環境のネットワーク設定を広げる必要があるかもしれない。xcresult の中身を読む `xcresulttool` は Xcode の道具なので Linux には無い。**CI 側で xcresult からスクリーンショットと失敗の要約を書き出して、PNG と テキストで成果物に置く**のが確実 | 本文からの読み取り（cloud-environments.md の許可ドメインの一覧と、Linux の VM であることから） | https://code.claude.com/docs/en/cloud-environments.md |
| Mac を介さずに CI の結果に反応させる他の道 | Claude Code: routines の GitHub トリガーは PR とリリースだけで、CI の完了では起動できない。Channels は CI の結果をローカルのセッションに押し込めるが、Mac が起きている必要がある。Cursor: Automations に「CI completed」「Workflow run completed」のトリガーがあり、Cloud Agents（Ubuntu）が動く。My Machines の Mac で Automations を動かせるかは書かれていない | 本文で確認（My Machines と Automations の組み合わせは本文を探したが記述なし） | https://code.claude.com/docs/en/routines.md 、https://code.claude.com/docs/en/channels.md 、https://cursor.com/docs/cloud-agent/automations.md |
| エージェント自体を macOS ランナーで動かせるか | Codex の GitHub Action は「Linux か macOS のランナーで動かす」と明記。Claude Code の GitHub Actions の文書の例は `ubuntu-latest` だけで、macOS について書いていない。macOS ランナーで Claude Code を動かし、XcodeBuildMCP でシミュレータを操作させる構成は技術的には組めるが、公式の案内は無い | 前半は本文で確認、後半は本文からの読み取り | https://learn.chatgpt.com/docs/github-action.md 、https://code.claude.com/docs/en/github-actions.md |

## 問い4: Mac が寝ているとき、実機

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Claude Code は Mac が寝ていると動くか | Remote Control は Mac の上のプロセスなので、寝ている間は止まり、起きると再接続する（"if your laptop sleeps … Claude Code reconnects automatically when your machine comes back online"）。Desktop のスケジュールは Mac が起きていないと飛ばされ、「Keep computer awake」を入れても「蓋を閉じると眠る」 | 本文で確認 | remote-control.md、https://code.claude.com/docs/en/desktop-scheduled-tasks.md |
| Codex は | Remote は「起きていてオンラインのホスト」が要る。「Mac のノートは、蓋を開けて電源につないでいれば使える。蓋を閉じるなら外部ディスプレイもつなぐ。スリープを選ぶと止まる」 | 本文で確認 | https://learn.chatgpt.com/docs/remote-connections.md |
| Cursor は | My Machines の worker は、セッションの間オンラインでいる必要がある。computer use にはログインした GUI のセッションが要り、再起動に備えて自動ログインと、ディスプレイをスリープさせない設定を勧めている | 本文で確認 | https://cursor.com/docs/cloud-agent/self-hosted/choose-runtime.md 、computer-use.md |
| Mac を閉じているときに回せるもの | Claude Code のクラウドのセッションと routines（Mac が切れていても動く）、Codex cloud、Cursor の Cloud Agents と Automations、GitHub Actions、Xcode Cloud。ただしどれも iOS のビルドはクラウド側（Linux）ではできず、iOS の部分は CI に任せる | 本文で確認（各サービスの記述）、組み合わせは本文からの読み取り | 上の各ページ |
| 実機をエージェントに操作させられるか | Claude Code のシミュレータ画面は「シミュレータだけで、実機の iPhone や iPad は操作できない」（"can't control a physical iPhone or iPad"）。XcodeBuildMCP の UI 操作はシミュレータだけ（実機はビルド、インストール、起動、テスト）。Xcode 27 の MCP の説明もシミュレータの起動を挙げている | 本文で確認 | desktop-ios-simulator.md、XcodeBuildMCP の manifests、Xcode 27 リリースノート |
| 実機でどこまで自動にできるか | XCTest・XCUITest を実機で回すこと（XcodeBuildMCP の test_device、`xcodebuild test`）は自動にできる。Xcode 27 と iOS 27 なら Wi-Fi でペアリングでき、ケーブル無しで動かせる。Mac とiPhone が同じネットワークにある必要がある | 本文で確認（test_device と Device Hub の文書）、自動化の範囲は本文からの読み取り | XcodeBuildMCP、https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub |
| HealthKit のバックグラウンド配信 | 「バックグラウンドのクエリはシミュレータでは動かない。実機で試すこと」（"Background server queries aren't supported on the Simulator. Be sure to test your background queries on a device."）。他アプリで体重を書いて nu-tori が起こされるか、は実機で人が確かめる。エージェントには、実機のログ（Console や `log` の出力）を渡して読ませる形にする | 前半は本文で確認、後半は本文からの読み取り | https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:) |

## 問い5: 費用と制約

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Claude の料金 | Pro 月 20 ドル（年払いで月 17 ドル）、Max 月 100 ドルから、Team は2〜150人で1席 20〜25 ドル（Premium 席 100〜125 ドル）。クラウドのセッションは「別の計算料金は無く、プランの上限に数える」 | 本文で確認 | https://claude.com/pricing 、desktop.md |
| Claude Code の機能とプラン | シミュレータ画面: Pro・Max・Team・Enterprise（HIPAA の構成を除く）。computer use: Pro・Max のみ。Remote Control: 全プラン（Team・Enterprise は管理者が有効化）。self-hosted environments: Team・Enterprise のみ。routines: 1日に始められる回数の上限あり、GitHub イベントは1時間の上限あり | 本文で確認 | 上の各ページ、routines.md |
| Codex の料金 | ChatGPT の Free、Go（8 ドル）、Plus（20 ドル）、Pro（100 ドルから）、Business などに含まれる | 本文で確認 | https://learn.chatgpt.com/docs/pricing.md |
| Cursor の料金 | Pro 月 20 ドル、Pro Plus 60 ドル、Ultra 200 ドル、Teams 1席 40 ドル。Cloud Agents はモデルの API 料金で課金し、最初に使用上限を決める。My Machines では自分の機械の費用も持つ。Team Pools は Enterprise | 本文で確認 | https://cursor.com/docs/models-and-pricing.md 、https://cursor.com/docs/cloud-agent.md 、self-hosted.md |
| Mac の台数と同時実行 | Claude Code: シミュレータ画面は1セッション4台まで、セッションごとに別のシミュレータ。computer use は Mac 全体で1セッションだけ。Remote Control の server mode は既定で32セッションまで。Cursor: My Machines は1台の Mac で複数のエージェントを動かせる。1人 200 台まで。Xcode 27 はプレビュー用のシミュレータ数を Mac の資源に合わせて抑える | 本文で確認 | desktop-ios-simulator.md、computer-use.md、remote-control.md、my-machines.md、self-hosted.md、Xcode 27 リリースノート（105131888） |
| 1台の Mac で並列に回すときの注意 | シミュレータの UI 操作は、セッションごとにシミュレータを分ければ並べられる（Claude のシミュレータ画面、XcodeBuildMCP の simulatorId）。computer use は画面全体を使うので1つだけ。ビルドは CPU を奪い合うので、一人開発の Mac では同時に2〜3本が現実的 | 前半は本文で確認、後半は本文からの読み取り | 上の各ページ |
| 権限の確認で止まる場所 | Xcode の MCP の接続許可、macOS のアクセシビリティ・画面収録の許可（computer use）、Claude のシミュレータ画面の端末ごとの許可、Codex・Cursor のアプリ承認。Xcode 26.3 の既知の問題として、デスクトップ、ダウンロード、書類フォルダにあるプロジェクトへのアクセスを一度拒否すると、アプリの中からは元に戻せない（システム設定のファイルとフォルダで許可し直すか、プロジェクトをそれ以外の場所に置く） | 本文で確認 | Xcode 26.3 リリースノート、各ツールの文書 |

## ツールごとの整理

| | Claude Code | Codex | Cursor |
|---|---|---|---|
| Mac の上: ビルドとテスト | Bash、Xcode の MCP、XcodeBuildMCP | Xcode の中の Codex、Xcode の MCP、Build iOS Apps（XcodeBuildMCP） | Xcode の MCP（公式ページあり）、XcodeBuildMCP |
| Mac の上: シミュレータの操作 | Desktop のシミュレータ画面（Xcode 26.x のみ）、CLI の computer use（Pro・Max）、MCP | Build iOS Apps、Computer Use | MCP |
| SwiftUI プレビュー | Xcode の MCP（RenderPreview） | 同左、ios-simulator-browser | 同左 |
| クラウド（管理された環境） | Ubuntu。iOS は不可 | Ubuntu。iOS は不可 | Ubuntu。iOS は不可 |
| 自分の Mac をクラウドの実行先に | self-hosted environments（Team・Enterprise） | 見当たらない | My Machines（有料プラン） |
| 外出中にスマホから | Remote Control、Dispatch | Codex Remote | Cursor iOS アプリ（Cloud Agents、My Machines を選べる） |
| CI の失敗への反応 | クラウドの Auto-fix（PR 単位） | GitHub Action（macOS ランナー可）、Code Review | Automations（CI completed トリガー） |

（表の各項目は上の各表で出典を示した）

## おすすめ

**普段は「Mac の上の Claude Code（CLI）＋ XcodeBuildMCP ＋ Xcode の MCP」、外出中で Mac が起きているときは「Remote Control」、夜間や Mac を閉じているときは「クラウドの Claude Code ＋ GitHub Actions の macOS ランナー（Auto-fix）」。実機は人が確かめる。**

1. **普段の開発（Mac の上）**
   - Claude Code の CLI に MobileBuildMCP（旧 XcodeBuildMCP）と Xcode の MCP の両方を足す。シミュレータの操作、スクリーンショット、ログ、テストは MobileBuildMCP を主に使い（Xcode を開いておかなくても動き、Xcode 27 に対応済み）、SwiftUI プレビューの確認（ライト・ダーク、文字サイズ違い）とビルドログの細かい読み取りは Xcode の MCP を使う（本文からの読み取り）。
   - Claude Code Desktop のシミュレータ画面は見ながら一緒に触れるので便利だが、Xcode 27 に対応するまでは Xcode 26.x を並べる必要がある。iOS 27 の SDK の機能を使うなら、当面は CLI ＋ MCP を主にする。
   - `AGENTS.md` に「変更したら test_sim を回し、関係する画面を開いてスクリーンショットで確かめる」「UI テストは XCUITest で書き、スクリーンショットを XCTAttachment で残す」と書き、検証の手順を固定する。
   - CLI の computer use は、Pro・Max で使えるが画面を占有し1セッションに限られるので、MCP で足りない時の最後の手段にする。
2. **外出中（Mac は電源につなぎ、起きている）**
   - Mac で `claude remote-control --spawn worktree` を常に動かしておき、スマホの Claude アプリから Mac のデバイスを選んで作業を始める。Mac 側の MCP とシミュレータがそのまま使える。Mac のスリープは切っておく（蓋を閉じるなら、Codex の文書が書くとおり外部ディスプレイが要ると考えておく。Claude の文書は「蓋を閉じると眠る」とだけ書いている）。
3. **夜間や Mac を閉じているとき**
   - クラウドの Claude Code（Linux）に、UI を含まない作業（Swift パッケージに分けた計算ロジック、API クライアント、テストの追加）を任せる。Linux でも Swift のツールチェーンで Swift パッケージのテストは回せる（`swift-vs-react-native.md`）。
   - PR を出すと GitHub Actions の macOS ランナーが `xcodebuild test`（XCUITest を含む）を回し、失敗の要約とスクリーンショットを PNG・テキストで成果物に出す。クラウドの Claude Code の Auto-fix がその失敗を読んで直す。リポジトリが非公開なら macOS は1分 0.062 ドルかかるので、夜間は必要な PR だけに絞る。
   - Xcode Cloud（月 25 時間は無料）は TestFlight への配布に使う。エージェントに結果を読ませる道（App Store Connect API）はあるが、GitHub の PR に結果が出る Actions の方がクラウドのエージェントとつなぎやすい（本文からの読み取り）。
4. **実機（HealthKit のバックグラウンド配信、カメラ）**
   - エージェントに任せられるのは、実機へのビルドとインストールと XCTest まで。他アプリで体重を書いて nu-tori が起こされるかは、人が実機で確かめ、ログをエージェントに渡して原因を探させる。

**別の選択肢**: Cursor の My Machines は「クラウドのエージェントの実行先を自分の Mac にする」ことを個人の有料プランでできる唯一の公式の仕組みで、Mac が起きていれば Mac の上の検証をクラウドの画面やスマホから回せる。ただし Mac が眠れば止まる点は Remote Control と同じなので、Claude Code を主に使うなら Remote Control で足りる（本文からの読み取り）。Claude Code の self-hosted environments は Team（2人から）が要るので、一人開発には向かない。

## 主なリスクと手当て

| リスク | 手当て（本文からの読み取り） |
|---|---|
| 仕組みが毎週変わる（Claude のシミュレータ画面の Xcode 27 対応、Xcode の無人向け MCP のプレビュー、MobileBuildMCP への改名） | MCP の設定と `AGENTS.md` の検証手順を1か所にまとめ、変わったら直す。月に一度この調査を見直す |
| Xcode の MCP は Xcode を開いておく必要があり、許可ダイアログで止まる | 無人で回す部分は MobileBuildMCP（`xcodebuild`・`simctl` ベース）に寄せる。Xcode 27 の `xcrun mcp-server` は安定版になってから試す |
| Mac が寝るとローカルの仕組みが全部止まる | 夜間は CI ＋ クラウドのエージェントに切り替える前提で、作業を「UI 以外（クラウド）」と「UI の確認（Mac）」に分けておく |
| CI の成果物をクラウドのエージェントが読めない | xcresult をそのまま渡さず、CI 側で PNG と要約テキストに書き出す。必要ならクラウド環境の許可ドメインを足す |
| 実機の挙動（HealthKit のバックグラウンド）はエージェントが確かめられない | 早い時期に実機での確認手順を決め、ログの取り方を `AGENTS.md` に書く |
| 画面操作の権限が広い（computer use、`--unsafe-always-allow-all-agents`） | シミュレータの操作は専用の MCP で行い、Mac 全体を操作する computer use は必要なときだけ有効にする |

## 出典一覧

Apple（開発者向けドキュメントとリリースノートは JSON で取得。2026-09-24）
- Giving external agents access to Xcode: https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode
- Setting up coding intelligence: https://developer.apple.com/documentation/xcode/setting-up-coding-intelligence
- Extending and customizing agents: https://developer.apple.com/documentation/xcode/extending-and-customizing-agents
- Managing your simulated and physical devices in Device Hub: https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub
- Xcode 26.3 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes
- Xcode 27 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
- Xcode 27.1・27.2 beta Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes 、https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes
- enableBackgroundDelivery(for:frequency:withCompletion:): https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)
- Xcode Cloud: https://developer.apple.com/documentation/xcode/xcode-cloud 、料金 https://developer.apple.com/xcode-cloud/
- Xcode Cloud workflows and builds（App Store Connect API）: https://developer.apple.com/documentation/appstoreconnectapi/xcode-cloud-workflows-and-builds 、CiArtifact: https://developer.apple.com/documentation/appstoreconnectapi/ciartifact

Anthropic（Claude Code の文書は Markdown 版を取得。2026-09-24）
- Test iOS apps in the simulator: https://code.claude.com/docs/en/desktop-ios-simulator.md
- Computer use（CLI）: https://code.claude.com/docs/en/computer-use.md
- Desktop application: https://code.claude.com/docs/en/desktop.md
- Remote Control: https://code.claude.com/docs/en/remote-control.md
- Use Claude Code in the cloud: https://code.claude.com/docs/en/claude-code-on-the-web.md
- Configure cloud environments: https://code.claude.com/docs/en/cloud-environments.md
- Self-hosted environments: https://code.claude.com/docs/en/self-hosted-environments.md 、quickstart: https://code.claude.com/docs/en/self-hosted-environments-quickstart.md 、reference: https://code.claude.com/docs/en/self-hosted-environments-reference.md
- Routines: https://code.claude.com/docs/en/routines.md
- Desktop scheduled tasks: https://code.claude.com/docs/en/desktop-scheduled-tasks.md
- Channels: https://code.claude.com/docs/en/channels.md
- Claude Code GitHub Actions: https://code.claude.com/docs/en/github-actions.md
- What's new（2026-w30、w34）: https://code.claude.com/docs/en/whats-new/2026-w30.md 、https://code.claude.com/docs/en/whats-new/2026-w34.md
- Changelog: https://code.claude.com/docs/en/changelog.md
- 料金: https://claude.com/pricing

OpenAI（Codex の文書は Markdown 版を取得。2026-09-24）
- Codex の文書の索引: https://developers.openai.com/codex/llms.txt
- Computer Use: https://learn.chatgpt.com/docs/computer-use.md
- Codex cloud: https://learn.chatgpt.com/docs/cloud.md 、Cloud environments: https://learn.chatgpt.com/docs/environments/cloud-environment.md 、Codex environments: https://learn.chatgpt.com/docs/environments/modes.md
- Codex Remote: https://learn.chatgpt.com/docs/remote.md 、Remote connections: https://learn.chatgpt.com/docs/remote-connections.md
- Scheduled tasks（automations）: https://learn.chatgpt.com/docs/automations.md
- Codex GitHub Action: https://learn.chatgpt.com/docs/github-action.md
- Plugins: https://learn.chatgpt.com/docs/plugins.md
- Pricing: https://learn.chatgpt.com/docs/pricing.md
- Codex manual: https://learn.chatgpt.com/docs/codex-manual.md
- openai/plugins（build-ios-apps 0.1.2、コミット 2026-09-11）: https://github.com/openai/plugins
- openai/codex-universal: https://github.com/openai/codex-universal

Cursor（Markdown 版を取得。2026-09-24）
- Xcode: https://cursor.com/docs/integrations/xcode.md
- Cloud Agents: https://cursor.com/docs/cloud-agent.md 、setup: https://cursor.com/docs/cloud-agent/setup.md 、capabilities: https://cursor.com/docs/cloud-agent/capabilities.md
- Self-Hosted Machines: https://cursor.com/docs/cloud-agent/self-hosted.md 、My Machines: https://cursor.com/docs/cloud-agent/self-hosted/my-machines.md 、Choose runtime: https://cursor.com/docs/cloud-agent/self-hosted/choose-runtime.md 、Computer use: https://cursor.com/docs/cloud-agent/self-hosted/computer-use.md
- Automations: https://cursor.com/docs/cloud-agent/automations.md
- Models and pricing: https://cursor.com/docs/models-and-pricing.md

GitHub
- GitHub Actions の課金: https://docs.github.com/en/billing/concepts/product-billing/github-actions 、ランナーの料金: https://docs.github.com/en/billing/reference/actions-runner-pricing
- actions/runner-images（macOS 26、Xcode 27 プレビュー）: https://github.com/actions/runner-images
- anthropics/claude-code-action: https://github.com/anthropics/claude-code-action

第三者（準公式）
- getsentry/XcodeBuildMCP（MobileBuildMCP 2.7.1、2026-09-23）: https://github.com/getsentry/XcodeBuildMCP
