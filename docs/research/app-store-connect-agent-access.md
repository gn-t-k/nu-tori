# エージェントが App Store Connect API で Xcode Cloud・TestFlight・フィードバックを読む

調査日: 2026-10-03
対象: エージェントが App Store Connect API で、(1) Xcode Cloud のビルドの成否と失敗のログ・問題、(2) TestFlight に版が配られたか、(3) TestFlight のフィードバック（スクリーンショットつき・クラッシュつき）とクラッシュのログを読み、(4) App Store Connect のウェブフックで何が知らせられるかを、ローカル（Mac の Claude Code・Codex・Cursor）とクラウド（Claude Code on the web のネット Full、Cursor の Cloud Agents）のどこでも使う方法。前の調査は `docs/research/sentry-agent-access.md`（Sentry を読む道具。Claude Code on the web と Cursor の Cloud Agents の秘密の値の置き場はここで調べ済み）、`docs/research/observability.md` の「3. Apple」（TestFlight のフィードバックの中身と、API があること）、`docs/research/agent-tools-setup.md`（各ツールが MCP の設定をどこから読むか）。重なる所は繰り返さず、そちらを指す

> **確認の方法と限界**
> - Apple の App Store Connect API の OpenAPI の仕様（`https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip`、`info.version` 4.5、ファイルの日付 2026-09-23）を落とし、パス・パラメータ・スキーマ・列挙の値を `jq` で読んだ。これを「仕様で確認」と書く。
> - Apple の文書は developer.apple.com の DocC の JSON（`https://developer.apple.com/tutorials/data/documentation/<パス>.json`）で本文を読んだ。役割の表は `https://developer.apple.com/support/roles/` の HTML を読んだ（いずれも 2026-10-03）。
> - Xcode Cloud が GitHub に何を書くかは、このリポジトリの main のコミットに付いたチェックを `gh api` で読んで確かめた（「観察」と書く）。
> - 第三者の CLI（`asc`）は GitHub のリポジトリを clone して文書とソースを読み、Homebrew の版は formulae.brew.sh の JSON、npm の候補は registry.npmjs.org の検索で確かめた。Apple の `altool` は手元の Xcode（altool 27.0.5）の `--help` を読んだ。
> - Claude Code は code.claude.com/docs、Cursor は cursor.com/docs の Markdown 版を読んだ。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。仕様・ソースで確かめたものは「仕様で確認」「ソースで確認」と書く（次の版で変わりうるので、文書の約束より弱い）。本文やソースから推し量ったものは「本文からの読み取り」、探しても記述が無かったものは「本文を探したが記述なし」と書く。
> - **App Store Connect のアカウントでは何も動かしていない**（API キーを作っていない。API は鍵なしで `GET /v1/apps` が 401 を返すことだけ確かめた）。JWT は使い捨ての EC 鍵で、Node 22 の `node:crypto` だけで ES256 の署名ができ、検証が通ることを確かめた。Cursor の Cloud Agents でも Claude Code on the web でも動かしていない。二次情報（ブログ、記事、SNS）は使っていない。

## 結論の要約

- **勧める形: Node の短いスクリプトを `scripts/app-store-connect` に1本置き、GET だけを送らせる。チームの API キー（役割 Developer）で JWT をその場で作る。MCP は置かない。** 5つの場所すべてで動く見込みがあるのはこれ（本文からの読み取り。下の「場所ごとの見込み」）。理由:
  - **Apple の公式の CLI・MCP で、上の1〜3を読めるものは無い**。Apple の `altool` は JWT を作れる（`--generate-jwt`）が、Xcode に入っているので Mac でしか動かず、読めるのはアップロードの処理の状態（`--build-status`）だけ（観察、altool 27.0.5 の `--help`）。Xcode の MCP（`xcrun mcpbridge`）は Xcode を開いた Mac でしか動かない（`agent-tools-setup.md`、`agent-ios-verification.md`）
  - 第三者の CLI でいちばん整っている `asc`（rorkai/App-Store-Connect-CLI、Homebrew の `asc` 5.9.1）は1〜3をすべて読め、読むだけのモードもある（ソースで確認）。ただし**テレメトリが既定でオン**（`rork.com` に送る）、**1週間に6回出る速さ**で、.p8 の鍵そのものを渡す相手としては重い。Claude Code on the web では GitHub の proxy が、つないでいないリポジトリのリリースの資産を 403 にするので、落とし方も工夫が要る（本文で確認）
  - JWT は ES256 の署名だけで、Node 22 の標準の `node:crypto` で数十行で書ける（確かめた）。Node は Mac にも、Claude Code on the web（22 が既定）にもある（本文で確認）
- **キーの種類と役割**: **チームのキーを、役割 Developer で作る**のが、1〜3を読める中でいちばん狭い（本文で確認）。Developer は Xcode Cloud を「Read access only」、TestFlight のビルドを「Read-only access」で読め、フィードバックの API は「ADMIN・APP MANAGER・DEVELOPER」が使える。それより狭い役割（Marketing・Sales・Customer Support・Finance）は Xcode Cloud とフィードバックのどちらかが読めない。**個人のキーは、作った人の役割をそのまま持つ**ので、Account Holder の開発者が作ると全部の権限になる。**読むだけの役割は無い**: Developer はフィードバックを消せ（DELETE も同じ役割）、内部テストのグループにビルドを足せる（本文で確認）。だからスクリプトで GET だけに絞る
- **1. Xcode Cloud**: `ciProducts` → `ciProducts/{id}/buildRuns`（`sort=-number`）→ `ciBuildRuns/{id}/actions` → `ciBuildActions/{id}/issues`（エラー・警告・テストの失敗の文と場所）・`/testResults`・`/artifacts`（`LOG_BUNDLE` などの期限つきの `downloadUrl`）で読める（仕様で確認）。**Xcode Cloud は GitHub のコミットにチェック（check run）と状態（commit status）の両方を書く**ので、成否だけなら `gh` で足りる（観察）。ただしチェックの中身は件数の表だけで、失敗の文は API で読む（観察）
- **2. TestFlight に配られたか**: `builds`（`processingState` が `VALID`、`version` がビルド番号）、`buildBetaDetail` の `internalBuildState`（`IN_BETA_TESTING` など）、`include=betaGroups` か `betaGroups/{id}/builds` で内部テストのグループに入ったかが分かる。Xcode Cloud のビルドから `ciBuildRuns/{id}/builds` でたどれる（仕様で確認）
- **3. フィードバックとクラッシュのログ**: 名前は `betaFeedbackScreenshotSubmissions`、`betaFeedbackCrashSubmissions`、`betaFeedbackCrashSubmissions/{id}/crashLog`（中身は `betaCrashLogs` の `logText`）（本文と仕様で確認）。**中身にはテスターのメール、端末の情報、自由記述のコメント、スクリーンショット（記録の中身が写りうる）が入る**ので、公開の Issue・PR に貼らない
- **4. ウェブフック**: App Store Connect API のウェブフックが知らせるのは、ビルドのアップロードの状態、**外部**テストのビルドの状態、App Store の版の状態、ベータのフィードバック（スクリーンショット・クラッシュ）の作成、背景アセット、別のマーケットプレイスの12種類（仕様で確認）。**内部テストの状態の変化と Xcode Cloud のビルドは、このウェブフックに無い**。Xcode Cloud には別のウェブフックがあり、ビルドを作った・始めた・終えたときに送る（本文で確認）。どちらも受けるサーバーが要り、作るのは App Manager 以上（本文で確認）。エージェントが直接受ける道は無いので、今は使わず、読むのは API を引く形にするのがよい（本文からの読み取り）
- **秘密の値の置き場**: Mac は altool と同じ `~/.appstoreconnect/private_keys/AuthKey_<Key ID>.p8`。クラウドは .p8 を **base64 で1行にして**環境変数に置く（Claude Code の環境変数は `.env` の形で、複数行は引用符で囲めると書くが、Cursor の Secrets に複数行の記述は無いため）。Cursor は種類を「Runtime Secret」にすると、会話とツールの結果で `[REDACTED]` に置き換わる（本文で確認）。Claude Code の API credentials は固定の値を付けるだけで、20 分ごとに作り直す JWT には使えない（本文からの読み取り）

## 前提: 2026-10-03 時点の版

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| App Store Connect API の仕様 | OpenAPI の `info.version` は 4.5。サーバーは `https://api.appstoreconnect.apple.com/`。認証は `bearerFormat: JWT` の Bearer | 仕様で確認 | 上の zip の `openapi.oas.json` |
| Apple の公式の道具 | `altool`（Xcode 27 の中、27.0.5）。`--generate-jwt`、`--list-apps`、`--build-status` などがある。鍵は `./private_keys`、`~/private_keys`、`~/.private_keys`、`~/.appstoreconnect/private_keys`、`$API_PRIVATE_KEYS_DIR` の `AuthKey_<api_key>.p8` を探す | 観察（`xcrun altool --help`） | 手元の Xcode |
| 第三者の CLI `asc` | Homebrew（homebrew/core）の `asc` 5.9.1、"Fast, lightweight CLI for App Store Connect"、MIT、Go。リポジトリは rorkai/App-Store-Connect-CLI（Go のモジュール名は `github.com/rudrankriyam/App-Store-Connect-CLI`）。GitHub のリリースに Linux・macOS・Windows の実行ファイル。5.6.0（09-25）から 5.9.1（10-01）まで6回出ている | 本文で確認 | https://formulae.brew.sh/api/formula/asc.json 、https://github.com/rorkai/App-Store-Connect-CLI/releases |
| npm の CLI・MCP | 検索で出る App Store Connect の MCP・SDK（`@akoskomuves/appstoreconnect-mcp`、`@mgcrea/mcp-appstore-connect`、`@chrischall/app-store-connect-mcp` など）は、どれも個人か小さな組織のもの。Apple のものは無い | 本文で確認（一覧） | https://registry.npmjs.org/-/v1/search?text=app%20store%20connect |
| claude.ai のコネクタ | Anthropic の MCP の登録簿に App Store Connect・TestFlight・Xcode Cloud のコネクタは無い | 観察（登録簿の検索） | — |

## 問い0: API キーの種類と役割

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| キーの種類 | チームのキーと個人のキー。"Team: Access to all apps, with varying levels of access based on selected roles." "Individual: Access and roles of the associated user." 個人のキーは Provisioning の API、売上と財務、`notaryTool` を使えない | 本文で確認 | https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api |
| チームのキーの役割 | 作るときに役割を選ぶ。役割は利用者の役割と同じ。"Team API keys can access all apps, regardless of their role." 作るには Admin が要る | 本文で確認 | 同上 |
| 最初に要ること | App Store Connect API へのアクセスを申し込めるのは Account Holder だけ（"is the only user that can … request access to the App Store Connect API"） | 本文で確認 | https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions |
| .p8 | 1回だけ落とせる。"Apple doesn't keep a copy of the private key." "Don't share your keys, store keys in a code repository" | 本文で確認 | creating-api-keys-for-app-store-connect-api |
| 失効 | 取り消したキーは戻せない。チームのキーは Admin が Users and Access から取り消す | 本文で確認 | https://developer.apple.com/documentation/appstoreconnectapi/revoking-api-keys |
| 回数の上限 | キーごとに1時間の上限（例は 3500）。応答の `X-Rate-Limit` に残りが出る。超えると 429 `RATE_LIMIT_EXCEEDED` | 本文で確認 | https://developer.apple.com/documentation/appstoreconnectapi/identifying-rate-limits |

### 役割ごとに、1〜3が読めるか

役割の表（`/support/roles/`）から、関係する行だけを抜いた。

| 機能（表の行の名前） | Admin | App Manager | Developer | Marketing | Sales・Finance・Customer Support |
|---|---|---|---|---|---|
| Use Xcode Cloud | Full | Full | **Read access only** | — | — |
| Manage TestFlight builds | Full | Full | **Read-only** | Read-only | — |
| Manage internal TestFlight groups and add builds | Full | Full | **Full**（書ける） | Full | — |
| Manage webhooks | Full | Full | — | — | — |
| Generate API keys | Full | — | — | — | — |

（本文で確認、https://developer.apple.com/support/roles/ ）

- フィードバックの API: "To manage beta feedback crash submissions, be sure you have one of the following user roles: `ADMIN` `APP MANAGER` `DEVELOPER`" "Both Team and Individual keys can use these endpoints with the correct role."（スクリーンショットも同じ）（本文で確認、https://developer.apple.com/documentation/appstoreconnectapi/beta-feedback-crash-submissions 、…/beta-feedback-screenshot-submissions ）
- よって **1〜3をすべて読める最も狭い役割は Developer**（本文からの読み取り、上の表と文から）
- **読むだけの役割は無い**。Developer は同じ API の DELETE（フィードバックを消す）を同じ役割の条件で使え、内部テストのグループにビルドを足せる（本文からの読み取り）。読むだけにするのは、キーの側ではなく、呼ぶ側（スクリプトが GET しか送らない）でやる
- 個人のキーは作った人の役割を持つので、nu-tori の開発者（Account Holder）が作ると Account Holder の権限になる。Developer の個人のキーにするには、別の Apple Account を Developer の役割で招く必要がある（本文からの読み取り）

### JWT の作り方と、絞り方

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| ヘッダー | `alg: ES256`、`kid: <Key ID>`、`typ: JWT` | 本文で確認 | https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests |
| チームのキーの中身 | `iss: <Issuer ID>`、`iat`、`exp`、`aud: appstoreconnect-v1`、任意で `scope` | 本文で確認 | 同上 |
| 個人のキーの中身 | `iss` の代わりに `sub: "user"` | 本文で確認 | 同上 |
| 寿命 | 多くの要求は 20 分を超える寿命を拒む。一度きりの要求なら「2分」が適当と書く。`scope` を持ち、GET だけで、対象が Xcode Cloud の一部（build-runs、build-actions、issues、products、workflows、test-results、repositories など）と Power and Performance Metrics なら、6か月までの寿命を受ける。**artifacts、builds、ベータのフィードバックはこの一覧に無い** | 本文で確認 | 同上（Determine the Appropriate Token Lifetime） |
| `scope` | 要求を表す文字列の配列（"The HTTP `GET` method"、パス、任意のクエリ）。どれにも合わない要求を拒む。`limit`・`cursor`・`sort` は照合で無視する | 本文で確認 | 同上（Determine the Scope of the Token） |
| `scope` の照合の細部 | パスだけを書いたときにクエリつきの要求が合うか、ワイルドカードが使えるか、`%5B` のように符号化した括弧をどう扱うか | 本文を探したが記述なし | 同上 |
| 署名の道具 | "there are a variety of open source libraries available online for creating and signing JWT tokens" と書くだけで、Apple の道具を挙げない | 本文で確認 | 同上 |
| Node だけで作れるか | 作れる。`crypto.sign("sha256", data, { key, dsaEncoding: "ieee-p1363" })` が ES256 の 64 バイトの署名を返し、検証も通った（Node 22.13.0、使い捨ての鍵） | 確かめた（この調査の手元） | — |

## 問い1: Xcode Cloud のビルドの成否と、失敗のログ・問題

### 読むための API

| 資源 | 読む API（GET） | 中身 | 確かさ |
|---|---|---|---|
| 製品 | `/v1/ciProducts?filter[app]=<app id>`、`/v1/apps/{id}/ciProduct` | `name`、`productType`（`APP`・`FRAMEWORK`） | 仕様で確認 |
| ワークフロー | `/v1/ciProducts/{id}/workflows`、`/v1/ciWorkflows/{id}` | 名前、開始の条件、アクション、`isEnabled` | 仕様で確認 |
| ビルド（実行） | `/v1/ciProducts/{id}/buildRuns`・`/v1/ciWorkflows/{id}/buildRuns`（`sort=number`・`-number`）、`/v1/ciBuildRuns/{id}` | `number`、日時、`sourceCommit`（`commitSha`・`message`・`author`）、`isPullRequestBuild`、`executionProgress`（`PENDING`・`RUNNING`・`COMPLETE`）、`completionStatus`（`SUCCEEDED`・`FAILED`・`ERRORED`・`CANCELED`・`SKIPPED`）、`startReason`、`cancelReason`（`AUTOMATICALLY_BY_NEWER_BUILD`・`MANUALLY_BY_USER`）、`issueCounts` | 仕様で確認 |
| アクション | `/v1/ciBuildRuns/{id}/actions`、`/v1/ciBuildActions/{id}` | `name`、`actionType`（`BUILD`・`ANALYZE`・`TEST`・`ARCHIVE`）、`completionStatus`、`issueCounts`、`isRequiredToPass` | 仕様で確認 |
| 問題 | `/v1/ciBuildActions/{id}/issues`、`/v1/ciIssues/{id}` | `issueType`（`ANALYZER_WARNING`・`ERROR`・`TEST_FAILURE`・`WARNING`）、`message`、`fileSource`（ファイルと行）、`category` | 仕様で確認 |
| テストの結果 | `/v1/ciBuildActions/{id}/testResults`、`/v1/ciTestResults/{id}` | クラス・名前・状態・場所・`message` | 仕様で確認 |
| 成果物（ログ） | `/v1/ciBuildActions/{id}/artifacts`、`/v1/ciArtifacts/{id}` | `fileType`（`ARCHIVE`・`ARCHIVE_EXPORT`・`LOG_BUNDLE`・`RESULT_BUNDLE`・`TEST_PRODUCTS`・`XCODEBUILD_PRODUCTS`・`STAPLED_NOTARIZED_ARCHIVE`）、`fileName`、`fileSize`、`downloadUrl`。"the returned download URL is only valid for a limited amount of time" | 仕様で確認、期限は本文で確認（https://developer.apple.com/documentation/appstoreconnectapi/get-v1-ciartifacts-_id_ ） |
| TestFlight のビルドへ | `/v1/ciBuildRuns/{id}/builds` | 下の問い2の `builds` | 仕様で確認 |

- Apple の案内の順は、`ciProducts` → `ciProducts/{id}/workflows` → `ciWorkflows/{id}`（本文で確認、https://developer.apple.com/documentation/appstoreconnectapi/xcode-cloud-workflows-and-builds ）
- 失敗の調べ方は、`buildRuns` の新しいものの `completionStatus` を見て、`actions` で落ちたアクションを探し、`issues` の `message` と `fileSource` を読み、足りなければ `artifacts` の `LOG_BUNDLE` を `downloadUrl` から落とす（本文からの読み取り）。`LOG_BUNDLE` の中の形（zip か、何のファイルが入るか）は書かれていない（本文を探したが記述なし）
- 書き込みの API もある（`POST /v1/ciBuildRuns` でビルドを始める、ワークフローを作る・直す・消す）。Developer は「Read access only」なので使えないはず（本文からの読み取り）

### Xcode Cloud が GitHub に書くもの

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| PR に書くか | PR の変更で始まるワークフローなら、ビルドの状態を SCM の PR のページに書く（"Xcode Cloud reports the build status on your source code management (SCM) provider's webpage for a PR"）。GitHub では status checks として必須にでき、ビルド全体か特定のアクションを求められる | 本文で確認 | https://developer.apple.com/documentation/xcode/configuring-requirements-for-merging-a-pull-request |
| main への push で書くか（nu-tori の形） | 書く。main のマージのコミット（`5a7c4e3`、`5347463`）に、GitHub App「Xcode Cloud」（slug `xcode-cloud`、所有者 `apple`）の check run「`NuTori \| mainから内部テスト \| Archive - iOS`」と、commit status「`NuTori \| mainから内部テスト`」（説明 `succeeded`）の両方が付いていた。古いコミットには `cancelled` の check run もあった | 観察（`gh api repos/gn-t-k/nu-tori/commits/<sha>/check-runs`、`…/status`） | — |
| チェックの中身 | check run の `output.summary` は「Errors・Test Failures・Analysis Issues・Warnings」の件数の表だけ。`text` は空、注記（annotations）は 0。`details_url` は App Store Connect のビルドのページ（サインインが要る） | 観察（成功したビルドだけ。失敗したビルドの check run は、main の最近 80 件に無く見ていない） | — |
| Xcode Cloud が書くための条件 | Apple の GitHub App をリポジトリに入れる（"Review the GitHub app that Apple provides … choose to only install it for your project's repository"） | 本文で確認 | https://developer.apple.com/documentation/xcode/connecting-xcode-cloud-to-github |

よって、**成否と、どのコミットのビルドかは `gh` で足りる**。例（本文からの読み取り）:

```bash
gh api "repos/gn-t-k/nu-tori/commits/<sha>/check-runs" \
  --jq '.check_runs[] | select(.app.slug == "xcode-cloud") | [.name, .status, .conclusion] | @tsv'
```

- Claude Code on the web では `gh` が入っていて、GitHub の proxy を通して認証される（本文で確認、https://code.claude.com/docs/en/cloud-environments.md の GitHub proxy）。Cursor の Cloud Agents は GitHub の連携で「CI results on a branch」を待て、"A CI subscription waits until every check on the commit has completed"（本文で確認、https://cursor.com/docs/cloud-agent/capabilities.md ）。Xcode Cloud の check run もその「every check」に入ると読める（本文からの読み取り）
- 失敗の理由（どのファイルの何のエラーか）は check run の件数の表には無いので、API の `issues` を読む（観察と本文からの読み取り）

## 問い2: TestFlight に版が配られたか

| 問い | API と欄 | 確かさ |
|---|---|---|
| ビルドの一覧 | `GET /v1/builds?filter[app]=<app id>&sort=-uploadedDate`（`filter[version]`、`filter[processingState]`、`filter[preReleaseVersion.version]`、`filter[betaGroups]` などがある）、`/v1/apps/{id}/builds` | 仕様で確認 |
| ビルド番号 | `Build.version`: "The version number of the uploaded build."（`CFBundleVersion` にあたる）。表示の版（`1.2` など）は `preReleaseVersion` の `version` | 前半は本文で確認（https://developer.apple.com/documentation/appstoreconnectapi/build/attributes-data.dictionary ）、`CFBundleVersion` にあたるのは本文からの読み取り（altool の `--bundle-version <string> CFBundleVersion` とあわせて） |
| 処理の状態 | `processingState`: `PROCESSING`・`FAILED`・`INVALID`・`VALID`（"indicating that it is not yet available for testing"）。ほかに `expired`、`expirationDate`、`uploadedDate`、`buildAudienceType`（`INTERNAL_ONLY`・`APP_STORE_ELIGIBLE`） | 仕様で確認、説明は本文で確認 |
| 内部テストの状態 | `buildBetaDetail`（`include=buildBetaDetail` か `/v1/builds/{id}/buildBetaDetail`）の `internalBuildState`: `PROCESSING`・`PROCESSING_EXCEPTION`・`MISSING_EXPORT_COMPLIANCE`・`READY_FOR_BETA_TESTING`・`IN_BETA_TESTING`・`EXPIRED`・`IN_EXPORT_COMPLIANCE_REVIEW` | 仕様で確認 |
| グループに入ったか | `GET /v1/builds?filter[app]=<id>&include=betaGroups`、または `GET /v1/apps/{id}/betaGroups` でグループの ID を得て `GET /v1/betaGroups/{id}/builds`。`/v1/builds/{id}/relationships/betaGroups` は POST と DELETE だけで、GET は無い | 仕様で確認 |
| Xcode Cloud のビルドとのつながり | `GET /v1/ciBuildRuns/{id}/builds` | 仕様で確認 |
| 役割 | Developer は「Manage TestFlight builds: Read-only access」 | 本文で確認 |

nu-tori の「配られた」は、Xcode Cloud の `completionStatus` が `SUCCEEDED` で、そのビルドの `processingState` が `VALID`、`internalBuildState` が `IN_BETA_TESTING`、`betaGroups` に「初回リリーステストユーザーグループ」がある、と読める（本文からの読み取り）。`MISSING_EXPORT_COMPLIANCE` で止まっていれば、暗号の申告が要る（本文からの読み取り）。

## 問い3: TestFlight のフィードバックとクラッシュのログ

### 名前と API

| 資源 | 読む API（GET） | 確かさ | 出典 |
|---|---|---|---|
| スクリーンショットつきのフィードバック | `/v1/apps/{id}/betaFeedbackScreenshotSubmissions`、`/v1/betaFeedbackScreenshotSubmissions/{id}` | 本文と仕様で確認 | https://developer.apple.com/documentation/appstoreconnectapi/beta-feedback-screenshot-submissions |
| クラッシュのフィードバック | `/v1/apps/{id}/betaFeedbackCrashSubmissions`、`/v1/betaFeedbackCrashSubmissions/{id}` | 本文と仕様で確認 | …/beta-feedback-crash-submissions |
| クラッシュのログ | `/v1/betaFeedbackCrashSubmissions/{id}/crashLog`（"Get crash log information for a specific beta feedback crash submission."）、`/v1/betaCrashLogs/{id}`。中身は `logText`（文字列）だけ | 本文と仕様で確認 | …/get-v1-betafeedbackcrashsubmissions-_id_-crashlog |
| 絞り込み | 一覧は `filter[deviceModel]`・`filter[osVersion]`・`filter[appPlatform]`・`filter[devicePlatform]`・`filter[build]`・`filter[build.preReleaseVersion]`・`filter[tester]`、`sort`、`include`（`build`・`tester`） | 仕様で確認 | `openapi.oas.json` |
| 消す | 両方に DELETE がある。役割の条件は読むときと同じ | 本文で確認 | 同上 |

Xcode Organizer と App Store Connect の「Crashes」に出る、フィードバックを伴わないクラッシュ（App Store の利用者の分を含む）は、この API ではなく、`/v1/builds/{id}/diagnosticSignatures` などの Power and Performance Metrics and Logs の側にある（`observability.md` の 3. Apple）。今回は深く見ていない。

### 返る中身（どれを貼ってよいか）

| 欄 | 中身 | 公開の Issue・PR に貼るか（本文からの読み取り） |
|---|---|---|
| `email`（両方の submission） | テスターのメール。招待メールのテスターはメールが出る（`observability.md`） | **貼らない** |
| `tester` の関係（`betaTesters`） | `email`、`firstName`、`lastName`、`inviteType`、`state`、`appDevices`（機種・OS・アプリのビルド） | **貼らない** |
| `comment` | テスターの自由記述 | **貼らない**。要約も、記録の中身（料理の名前、体重、kcal など）を含めない |
| `screenshots`（`url`・`width`・`height`・`expirationDate`） | 画像の期限つきの URL。nu-tori の画面なので記録の中身が写りうる | **画像も URL も貼らない**。URL は期限まで誰でも開ける鍵として扱う |
| `deviceModel`、`osVersion`、`architecture`、`appPlatform`、`devicePlatform`、`deviceFamily`、`buildBundleId` | 機種と OS と版 | 貼ってよい（Sentry のときと同じく、版・OS・件数まで） |
| `locale`、`timeZone`、`connectionType`、`batteryPercentage`、`diskBytesAvailable`・`diskBytesTotal`、`screenWidthInPoints`・`screenHeightInPoints`、`pairedAppleWatch`、`appUptimeInMilliseconds` | 端末の状態 | 原因に要るものだけを言葉で書く。並べて貼らない（組み合わせで人に近づく） |
| `crashLog` の `logText` | クラッシュのログの本文。形は書かれていない（本文を探したが記述なし）。端末から取る `.ips` には `deviceIdentifierForVendor`（`storeInfo` の中）、`incident`、`bootSessionUUID`、`procPath` などの識別子が入っていた（観察、開発者の端末の `.ips` の鍵の名前だけを見た） | **全文を貼らない**。貼るのは落ちたスレッドの関数名と、例外の種類まで |
| Xcode Cloud の `sourceCommit.author`、`message` | コミットの作者の表示名とメッセージ | このリポジトリは公開なので GitHub と同じもの。貼ってよい |
| `ciArtifacts` の `downloadUrl` | 期限つきの URL | **貼らない** |
| App の ID、チームの ID | App Store Connect の URL に入る | GitHub の check run の `details_url` にすでに公開で出ている（観察）。秘密ではない |

フィードバックの中身はエージェントの会話（各社のサーバー）に入る。ルートの `AGENTS.md` は人の声を TestFlight のフィードバックで受けると決めているので、読むこと自体は用途に合うが、スクリーンショットとコメントは記録の中身を含みうる（本文からの読み取り）。

## 問い4: App Store Connect のウェブフック

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 何の出来事か | `WebhookEventType` の12種類: `APP_STORE_VERSION_APP_VERSION_STATE_UPDATED`、`BUILD_UPLOAD_STATE_UPDATED`、`BUILD_BETA_DETAIL_EXTERNAL_BUILD_STATE_UPDATED`、`BETA_FEEDBACK_CRASH_SUBMISSION_CREATED`、`BETA_FEEDBACK_SCREENSHOT_SUBMISSION_CREATED`、背景アセットの4つ（`BACKGROUND_ASSET_VERSION_*`）、別のマーケットプレイスの3つ（`ALTERNATIVE_DISTRIBUTION_*`） | 仕様で確認 | `openapi.oas.json`、https://developer.apple.com/documentation/appstoreconnectapi/webhook-events |
| 内部テストの状態 | 無い。ベータの状態は "when the external beta build status changes" だけ | 仕様と本文で確認 | webhook-events |
| Xcode Cloud のビルド | App Store Connect API のウェブフックには無い（上の12種類）。Xcode Cloud に別のウェブフックがあり、"every time it creates, starts, and finishes a build" に送る。製品ごとに5つまで。Xcode の Report navigator か App Store Connect の Xcode Cloud の Settings で作る。中身にワークフロー・ビルド・アクション（`issueCounts`・`completionStatus`）・リポジトリ・PR が入る（例の `eventType` は `BUILD_COMPLETED`） | 本文で確認 | https://developer.apple.com/documentation/xcode/configuring-webhooks-in-xcode-cloud |
| 中身 | App Store Connect のものは ID と状態だけ（例: `betaFeedbackCrashSubmissionCreated` は `timestamp` と `relationships.instance` の ID と `self` のリンク）。中身は API で取り直す（"Use the information in the notification to make subsequent calls to the App Store Connect API to retrieve data."） | 本文で確認 | webhook-events |
| 作り方 | `POST /v1/webhooks`（`eventTypes`、`url`、`secret`、`app`）。署名は HMAC-SHA256 で `x-apple-signature: hmacsha256=<hex>`。`POST /v1/webhookPings` で試せ、`/v1/webhooks/{id}/deliveries` で配送の履歴を読める | 本文で確認 | https://developer.apple.com/documentation/appstoreconnectapi/configuring-webhook-notifications |
| 誰が作れるか | 役割の表の「Manage webhooks」は Account Holder・Admin・App Manager。Developer は無い | 本文で確認 | /support/roles/ |

エージェントは HTTP の要求を受けられないので、ウェブフックを使うには受けるサーバー（nu-tori なら Workers）を作り、そこから GitHub の Issue を立てるなどの形になる（本文からの読み取り）。Xcode Cloud の成否は GitHub のチェックで、フィードバックは API を引けば足りるので、今は作らなくてよい（本文からの読み取り）。

## 問い5: JWT を作る手段の比べ

```
                         1〜3を   Mac   Claude   Cursor   鍵を渡す相手        気になる点
                         読めるか        web      Cloud
Apple の altool           ×       ○     ×        ×        Apple              Xcode の中。読めるのは処理の状態だけ
Xcode の MCP              ×       ○※1   ×        ×        Apple              Xcode を開いた Mac だけ。App Store Connect を読まない
第三者の CLI（asc）       ○       ○     △※2     ○        rorkai（第三者）    テレメトリが既定でオン。ほぼ毎日出る
第三者の MCP（npm）       ○※3     ○     ○※4     △※5     個人の作者          公式でない。Cursor Cloud はリポジトリの MCP を読まない
自前の Node のスクリプト  ○       ○     ○        ○※6     なし（自分のコード）  ページ送りなどを自分で書く
```

- ※1 Mac で Xcode を起動しておく必要がある（`agent-tools-setup.md`）
- ※2 GitHub のリリースから落とすと、Claude Code on the web の GitHub の proxy が "a setup script that downloads release assets from an unattached repository gets a 403"（本文で確認、cloud-environments.md）。`asccli.sh/install` の導入スクリプトが中で何を落とすかは見ていない。Go が入っているので `go install` は通る見込み（本文からの読み取り）
- ※3 道具ごとに違う。今回は中身を読んでいない
- ※4 `.mcp.json` に書けばクラウドでも起動する（`sentry-agent-access.md` の※5 と同じ読み）
- ※5 Cloud Agents はリポジトリの `.cursor/mcp.json` を読むと書いていない。ダッシュボードに stdio のサーバーとして足せば VM の中で動く（`sentry-agent-access.md`）
- ※6 Cursor の VM に Node が入っているかは見ていない。Cloud Agents の環境は Ubuntu で、入れる手順（install・startup）を書ける（本文で確認、https://cursor.com/docs/cloud-agent/setup.md ）

### 第三者の CLI `asc` の中身

| 問い | 答え | 確かさ | 出典（rorkai/App-Store-Connect-CLI、fc973ef、2026-10-02） |
|---|---|---|---|
| 1〜3 | `asc xcode-cloud`（`build-runs`・`actions`・`issues`・`artifacts`・`test-results`）、`asc builds`、`asc testflight feedback`（`--include-screenshots`）、`asc testflight crashes`（`log`）、`asc webhooks` がある | 本文で確認 | commands/xcode-cloud.mdx、commands/feedback.mdx、commands/crashes.mdx |
| 認証 | `ASC_KEY_ID`・`ASC_ISSUER_ID`・`ASC_PRIVATE_KEY_PATH`、または `ASC_PRIVATE_KEY`（PEM）・`ASC_PRIVATE_KEY_B64`。Mac では OS のキーチェーンにも置ける | 本文で確認 | authentication.mdx、configuration/environment-variables.mdx |
| 読むだけのモード | `ASC_READ_ONLY=1` か `--read-only` で、POST・PATCH・PUT・DELETE を送る前に断り、終了コード 6（"Refuse every mutating request … before it is sent"） | 本文で確認 | concepts/read-only-mode.mdx |
| テレメトリ | "Telemetry is enabled by default for every runtime."。送り先の既定は `https://rork.com/cf-api/asc/v1/events`。引数・エラーの文・ID・パスは送らないと書く。`ASC_TELEMETRY_DISABLED=1` か `DO_NOT_TRACK=1` で止める | 本文で確認、送り先はソースで確認（internal/telemetry/client.go） | commands/telemetry.mdx |
| 役割の説明 | 「Customer Support: Read-only for reviews and feedback」と書くが、Apple の文書ではフィードバックの API は ADMIN・APP MANAGER・DEVELOPER だけ。Apple と食い違う | 本文で確認（両方） | authentication.mdx、Apple の beta-feedback-crash-submissions |
| ほか | `asc web` は Apple Account のパスワードとセッションの cookie で、API に無い操作をする | 本文で確認 | authentication.mdx |

### 勧めるもの: 自前の Node のスクリプト

- Apple は署名の道具を挙げず「オープンソースのライブラリ」に任せている（本文で確認）。ES256 は Node の標準だけで作れ、依存を足さずに済む（確かめた）
- .p8 は App Store Connect のすべてを Developer の範囲で動かせる鍵で、第三者のコードに読ませずに済む（本文からの読み取り）。`asc` を使うなら、`ASC_READ_ONLY=1`・`ASC_TELEMETRY_DISABLED=1` を起動スクリプトで決め、版を固定する
- GET だけを送る、`api.appstoreconnect.apple.com` の外へは送らない、JWT の寿命を 2 分にする、を1か所で守れる（本文からの読み取り）
- 返る JSON は JSON:API の形（`data`・`included`・`links.next`）のままで、エージェントは `jq` で読める（本文からの読み取り）

## 場所ごとに、秘密の値の置き場とネット

| 場所 | 鍵の置き場 | api.appstoreconnect.apple.com へ出られるか | 確かさ | 出典 |
|---|---|---|---|---|
| Mac（Claude Code・Codex・Cursor） | `~/.appstoreconnect/private_keys/AuthKey_<Key ID>.p8`（altool が探す場所の1つ。`chmod 600`）。Key ID と Issuer ID はシェルの環境変数 | 出られる | 場所は観察（altool の `--help`）、ほかは本文からの読み取り | — |
| Claude Code on the web | 個人の環境の Environment variables（`.env` の形、"Quote a value that spans multiple lines"）。"values are visible to anyone using the environment" なので共有の環境に置かない。変えた値は、動いているセッションでは VM が戻るまで古いまま | Full なら出られる（"Any domain"） | 本文で確認 | https://code.claude.com/docs/en/cloud-environments.md |
| Claude Code on the web の API credentials | 固定のキーをホストへの要求に proxy が付ける。キーはセッションに入らない | — | 本文で確認 | 同上 |
| Cursor の Cloud Agents | ダッシュボードの Secrets（環境変数として渡る）。種類「Runtime Secret」は "redacted from the agent's tool call results, chat transcript, commits, and commit messages" で `[REDACTED]` になる。ただし Terminal からは見える。環境ごとの Secrets もある | 既定で全部に出られる（"The agent has internet access by default"） | 本文で確認 | https://cursor.com/docs/cloud-agent/security-network.md 、setup.md |

- **.p8 の改行**: .p8 は PEM（`-----BEGIN PRIVATE KEY-----` と改行の入った本文）。Claude Code の環境変数は引用符で囲めば複数行を持てると書くが、Cursor の Secrets に複数行の扱いの記述は無い（本文を探したが記述なし）。**`base64 -i AuthKey_<Key ID>.p8 | tr -d '\n'` の1行にして置き、スクリプトで戻す**のが両方で同じに動く（本文からの読み取り）。スクリプトは、値が `BEGIN` を含めば PEM として読み、`\n` の2文字も改行に戻す
- **API credentials は使わない**: JWT は寿命が 20 分まで（6か月を受けるのは Xcode Cloud の一部の資源の GET だけで、builds・artifacts・フィードバックは入らない）なので、固定の値を付ける API credentials には向かない。Xcode Cloud の読み取りだけなら、`scope` つきの6か月の JWT を置く形はありうるが、`scope` は要求ごとのパスを並べる形で、ID が変わる `ciBuildActions/{id}` を前もって書けない（本文からの読み取り、上の JWT の表から）
- Codex Cloud は今回の対象の外。置くなら `sentry-agent-access.md` の Network secret の読みと同じで、`api.appstoreconnect.apple.com` を許可に足す（本文からの読み取り）

## nu-tori への当てはめ

ここは、上の表からの読み取り。決めるのは開発者で、決めたことはストック（`docs/agents/tooling.md`、`docs/agents/ios-release.md` など）に書く。

### 勧める形

```
成否だけ:   エージェント ──gh api──> GitHub の check run（app: xcode-cloud）
中身:       エージェント ──Bash──> scripts/app-store-connect get <パス> ──HTTPS──> api.appstoreconnect.apple.com
                                     │
                                     ├─ GET だけ。ホストは api.appstoreconnect.apple.com だけ
                                     ├─ JWT（ES256、寿命 2 分）を呼ぶたびに作る。依存なし（node:crypto）
                                     └─ 鍵: NU_TORI_ASC_PRIVATE_KEY（base64）か、~/.appstoreconnect/private_keys/AuthKey_<Key ID>.p8
キー:       チームのキー、役割 Developer、名前は用途がわかるもの（例「エージェントの読み取り」）
MCP:        置かない（3つの MCP の設定には何も足さない）
ウェブフック: 今は作らない
```

### 置くファイルの例

`scripts/app-store-connect`（実行できるようにする）:

```js
#!/usr/bin/env node
// エージェントと人が App Store Connect API を読むだけで呼ぶ。GET だけを送り、鍵の読み方と JWT の作り方をここ1か所に置く
import { createPrivateKey, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const api = "https://api.appstoreconnect.apple.com";

const fail = (message) => {
  console.error(message);
  process.exit(1);
};

const loadPrivateKey = (keyId) => {
  const inline = process.env.NU_TORI_ASC_PRIVATE_KEY;
  if (inline) {
    // クラウドの秘密の値は改行を持てないことがあるので、base64 の1行を正にし、\n を書いた PEM も受ける
    const pem = inline.includes("BEGIN")
      ? inline.replaceAll("\\n", "\n")
      : Buffer.from(inline, "base64").toString("utf8");
    return createPrivateKey(pem);
  }
  // altool が探す場所の1つにそろえる
  const path = join(homedir(), ".appstoreconnect", "private_keys", `AuthKey_${keyId}.p8`);
  try {
    return createPrivateKey(readFileSync(path, "utf8"));
  } catch {
    fail(`Not authenticated: NU_TORI_ASC_PRIVATE_KEY も ${path} も無い`);
  }
};

const keyId = process.env.NU_TORI_ASC_KEY_ID;
const issuerId = process.env.NU_TORI_ASC_ISSUER_ID;
if (!keyId || !issuerId) fail("Not authenticated: NU_TORI_ASC_KEY_ID と NU_TORI_ASC_ISSUER_ID が無い");
const privateKey = loadPrivateKey(keyId);

const token = () => {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  // 一度きりの要求には 2 分が適当と Apple が書くので、呼ぶたびに短い寿命で作る
  const unsigned = `${encode({ alg: "ES256", kid: keyId, typ: "JWT" })}.${encode({
    iss: issuerId,
    iat: now,
    exp: now + 120,
    aud: "appstoreconnect-v1",
  })}`;
  const signature = sign("sha256", Buffer.from(unsigned), { key: privateKey, dsaEncoding: "ieee-p1363" });
  return `${unsigned}.${signature.toString("base64url")}`;
};

const [command, target, ...flags] = process.argv.slice(2);
if (command !== "get" || !target?.startsWith("/v")) {
  fail("使い方: scripts/app-store-connect get '/v1/...' [--all]（GET だけ。--all で links.next をたどる）");
}

// 役割 Developer はフィードバックを消せるので、書き込みと、ほかのホストへの送信をここで断る
const toApiUrl = (value) => {
  const url = new URL(value, api);
  if (url.origin !== api) fail(`api.appstoreconnect.apple.com の外へは送らない: ${url.origin}`);
  return url;
};

const followAll = flags.includes("--all");
let url = toApiUrl(target);
const merged = { data: [], included: [] };
while (url) {
  const response = await fetch(url, { headers: { Authorization: `Bearer ${token()}` } });
  const body = await response.text();
  if (!response.ok) fail(`${response.status} ${body}`);
  const page = JSON.parse(body);
  if (!followAll) {
    console.log(JSON.stringify(page, null, 2));
    process.exit(0);
  }
  merged.data.push(...[page.data].flat());
  merged.included.push(...(page.included ?? []));
  url = page.links?.next ? toApiUrl(page.links.next) : null;
}
console.log(JSON.stringify(merged, null, 2));
```

- アプリの ID（Apple ID）は秘密ではない（GitHub の check run の URL に出ている）ので、`docs/agents/tooling.md` に書いてよい。最初に `scripts/app-store-connect get '/v1/apps?filter[bundleId]=app.nu-tori'` で確かめる
- `scope` の claim（要求ごとに絞る）を足せば、漏れた JWT でできることがさらに減るが、照合の細部が書かれていないので、足すなら動かして確かめてから（上の「JWT の作り方と、絞り方」）
- `asc` を選ぶなら、`scripts/sentry` と同じ形の起動スクリプトにし、`ASC_READ_ONLY=1`、`ASC_TELEMETRY_DISABLED=1`、`ASC_KEY_ID` などへの受け渡し、版の固定をそこに書く

ルートの `AGENTS.md`（または `docs/agents/tooling.md`）に足す一文の例:

```
- Xcode Cloud の成否は `gh api repos/gn-t-k/nu-tori/commits/<sha>/check-runs`（app が xcode-cloud）で見る。失敗の文、TestFlight のビルドの状態、TestFlight のフィードバックとクラッシュのログは `scripts/app-store-connect get '<パス>'` で読む（例: `/v1/ciProducts/<id>/buildRuns?sort=-number&limit=5`、`/v1/ciBuildRuns/<id>/actions`、`/v1/ciBuildActions/<id>/issues`、`/v1/builds?filter[app]=<id>&sort=-uploadedDate&include=buildBetaDetail,betaGroups`、`/v1/apps/<id>/betaFeedbackCrashSubmissions`、`/v1/betaFeedbackCrashSubmissions/<id>/crashLog`）。読んだフィードバックのメール・名前・コメント・スクリーンショット・クラッシュのログの全文・期限つきの URL は、公開の Issue・PR・コメントに貼らない。貼るのはビルド番号、状態、関数名、版・OS・機種、件数まで
```

### 開発者が手でやること

1. **API を使えるようにする**（まだなら）: Account Holder で App Store Connect の Users and Access > Integrations > App Store Connect API からアクセスを申し込む
2. **チームのキーを作る**: 同じ画面の Team Keys で Generate API Key。Access は **Developer**。Key ID と、画面の上の Issuer ID を控える。**.p8 は1回だけ落とせる**
3. **Mac**: `mkdir -p ~/.appstoreconnect/private_keys && mv AuthKey_<Key ID>.p8 ~/.appstoreconnect/private_keys/ && chmod 600 ~/.appstoreconnect/private_keys/AuthKey_<Key ID>.p8`。シェルの設定に `NU_TORI_ASC_KEY_ID` と `NU_TORI_ASC_ISSUER_ID` を書く
4. **Claude Code on the web**: 個人の環境（共有しない）の Environment variables に `NU_TORI_ASC_KEY_ID`、`NU_TORI_ASC_ISSUER_ID`、`NU_TORI_ASC_PRIVATE_KEY=<base64 -i AuthKey_<Key ID>.p8 | tr -d '\n' の出力>`。ネットは Full のままでよい
5. **Cursor の Cloud Agents**: ダッシュボードの Cloud Agents > Secrets に同じ3つ。`NU_TORI_ASC_PRIVATE_KEY` は種類を **Runtime Secret** にする。ネットを絞っているなら `api.appstoreconnect.apple.com` を足す（成果物のログを落とすなら、その `downloadUrl` のホストも）
6. 各場所で `scripts/app-store-connect get '/v1/apps?filter[bundleId]=app.nu-tori'` を一度走らせ、動いたかを `docs/agents/tooling.md` に書く
7. 鍵を失くした・漏れたら、Users and Access の Team Keys で取り消す（戻せない）。作り直したら、上の4か所を入れ替える

### 最小の権限

- **チームのキー、役割 Developer**。1〜3をすべて読める中でいちばん狭い（本文で確認）
- Developer でも書き込み（フィードバックを消す、内部テストのグループにビルドを足す、App 内課金を作るなど）ができる。読むだけにするのは `scripts/app-store-connect` の GET の制限と、`AGENTS.md` の一文による（本文からの読み取り）。エージェントは鍵を持つので、スクリプトを通さずに書き込みを送ることもできる。これを防ぐ手段は、Apple の側には `scope` の claim（JWT を作る側が決める）しか無い
- ウェブフックを作るなら App Manager 以上が要るが、今は作らない
- 個人のキーは使わない（開発者の個人のキーは Account Holder の権限になる）

### 確かめていないこと

- 実際の App Store Connect のアカウントに向けては、どの API も呼んでいない。Developer の役割で、`ciBuildRuns`・`ciIssues`・`ciArtifacts` の GET と、フィードバックの GET・`crashLog` が通ることは、文書の役割の表とフィードバックの文書からの読み取り
- 失敗した Xcode Cloud のビルドで、GitHub の check run の `output` に何が出るか（成功したものしか見ていない）
- `LOG_BUNDLE` の中身の形と、`downloadUrl` のホスト（Cursor でネットを絞るときに要る）
- `crashLog` の `logText` の形と、どの識別子が入るか（端末の `.ips` と同じかは書かれていない）
- `scope` の claim の照合の細部（クエリ、符号化、ワイルドカード）
- Cursor の Cloud Agents の VM に Node が入っているか、Secrets が複数行の値を保てるか
- `asc` の導入スクリプト（`asccli.sh/install`）が Claude Code on the web で通るか
- App Store Connect のウェブフックと Xcode Cloud のウェブフックは、作っても試してもいない

## 出典一覧

Apple（2026-10-03）
- App Store Connect API の OpenAPI の仕様（4.5）: https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip
- Creating API Keys for App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api
- Generating Tokens for API Requests: https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
- Revoking API Keys: https://developer.apple.com/documentation/appstoreconnectapi/revoking-api-keys
- Identifying Rate Limits: https://developer.apple.com/documentation/appstoreconnectapi/identifying-rate-limits
- Xcode Cloud Workflows and Builds: https://developer.apple.com/documentation/appstoreconnectapi/xcode-cloud-workflows-and-builds
- Read xcode cloud artifact information: https://developer.apple.com/documentation/appstoreconnectapi/get-v1-ciartifacts-_id_
- Beta feedback crash submissions: https://developer.apple.com/documentation/appstoreconnectapi/beta-feedback-crash-submissions
- Beta feedback screenshot submissions: https://developer.apple.com/documentation/appstoreconnectapi/beta-feedback-screenshot-submissions
- Read the Crash Log for a Beta Feedback Crash Submission: https://developer.apple.com/documentation/appstoreconnectapi/get-v1-betafeedbackcrashsubmissions-_id_-crashlog
- Build.Attributes: https://developer.apple.com/documentation/appstoreconnectapi/build/attributes-data.dictionary 、BetaTester.Attributes: https://developer.apple.com/documentation/appstoreconnectapi/betatester/attributes-data.dictionary 、CiArtifact.Attributes: https://developer.apple.com/documentation/appstoreconnectapi/ciartifact/attributes-data.dictionary
- Webhook notifications: https://developer.apple.com/documentation/appstoreconnectapi/webhook-notifications 、Understanding webhook events: https://developer.apple.com/documentation/appstoreconnectapi/webhook-events 、Configuring and parsing webhook notifications: https://developer.apple.com/documentation/appstoreconnectapi/configuring-webhook-notifications
- Xcode Cloud: https://developer.apple.com/documentation/xcode/xcode-cloud 、Configuring webhooks in Xcode Cloud: https://developer.apple.com/documentation/xcode/configuring-webhooks-in-xcode-cloud 、Configuring requirements for merging a pull request: https://developer.apple.com/documentation/xcode/configuring-requirements-for-merging-a-pull-request 、Connecting Xcode Cloud to GitHub: https://developer.apple.com/documentation/xcode/connecting-xcode-cloud-to-github 、Setting up your project to use Xcode Cloud: https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud
- Role permissions: https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions 、役割ごとの機能の表: https://developer.apple.com/support/roles/
- altool: 手元の Xcode の `xcrun altool --help`（27.0.5）

第三者の道具（2026-10-03）
- rorkai/App-Store-Connect-CLI（fc973ef）: https://github.com/rorkai/App-Store-Connect-CLI — authentication.mdx、configuration/environment-variables.mdx、concepts/read-only-mode.mdx、commands/telemetry.mdx、commands/xcode-cloud.mdx、commands/feedback.mdx、commands/crashes.mdx、internal/telemetry/client.go
- Homebrew: https://formulae.brew.sh/api/formula/asc.json
- npm の検索: https://registry.npmjs.org/-/v1/search?text=app%20store%20connect

GitHub（観察、2026-10-03）
- `gh api repos/gn-t-k/nu-tori/commits/<sha>/check-runs`、`…/status`（main の `5a7c4e3`、`5347463` ほか）

Anthropic（Markdown 版。2026-10-03）
- Configure cloud environments: https://code.claude.com/docs/en/cloud-environments.md （Set environment variables、Add API credentials、Access levels、GitHub proxy、Installed tools）

Cursor（Markdown 版。2026-10-03）
- Cloud Agents の setup: https://cursor.com/docs/cloud-agent/setup.md 、security and network: https://cursor.com/docs/cloud-agent/security-network.md 、capabilities: https://cursor.com/docs/cloud-agent/capabilities.md
