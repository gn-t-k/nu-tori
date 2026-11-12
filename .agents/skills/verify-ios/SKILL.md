---
name: verify-ios
description: "nu-tori の iPhone アプリ（ios/）を Mac のシミュレーターで動かし、UI テストと、偽の同期サーバーの場面か手元のサーバーにつないで開いたアプリを触って、触れた機能が動くことを証拠つきで確かめる。PR を出す前と PR に push する前の確かめ（docs/agents/review.md の「確かめの回し方」。かかるかは同じ文書の表）で使う。動かすのは Mac のセッションだけで、クラウドのセッションでは、確かめられないときの書き方を引くのに使う。"
---

# アプリを動かして確かめる

アプリのデバッグビルドをシミュレーターで開き、ユーザーと同じ画面の操作で機能を通し、操作のあとの画面で動いたことを示す。テストが通ることとは別に、組んだアプリの画面で、操作から記録の見え方までがつながったかを見る。

アプリはサーバーにつながず、UI テストと同じ場面の仕組み（起動の値）で、サインインの状態と API を差し替えた場面で開く（`ios/NuTori/UITesting/UITestLaunch.swift`）。差し替えるのは本番でも端末とサーバーを分けている境目（API、Sign in with Apple、ヘルスケア、写真を選ぶ画面、StoreKit）だけで、画面・送り待ち・キャッシュ・同期の段取りは本物が動く。サーバーの側は `verify-server` で確かめる。API の境目にかかる変更では、API だけを `verify-server` で立てた手元のサーバーにつなぐ（下の「手元のサーバーにつないで動かす」）。

道具はこのフォルダの `scripts/` にある。回のフォルダを取る道具は、引数なしで呼ぶと使い方を言って止まる。下では `S=.agents/skills/verify-ios/scripts` とする（リポジトリの直下から呼ぶ）。macOS でだけ動く。

確かめ方は2つある。地図の機能のファイルが、入口ごとにどちらを使うかを書いている。

1. **UI テストのある流れ**: その UI テストの結果で示す。全件の回の該当テストを指すか、`ui-test.sh` で回すかは、`ios/AGENTS.md` の「確かめる」による。流れの正本は UI テスト（`docs/agents/testing.md` の「ロジックと UI の分担」）
2. **UI テストの無い入口と、変えた画面を自分の目で見るとき**: `start.sh` で端末を作り、`launch.sh` で場面を選んで開き、MobileBuildMCP で触る

## UI テストで確かめる

```bash
run=$($S/ui-test.sh RecordWeightFromComposerUITests CorrectWeightFromWeightScreenUITests)
```

- `scripts/check ios-ui-test --only <クラス>[/<メソッド>]` を回す。UI テストは回すたびに作る複製のシミュレーター（`docs/agents/ios-mac.md` の「UI テストのシミュレータ」）で動くので、共有の iPhone と取り合わない
- 新しい回のフォルダ（`.scratch/verify-ios/<時刻>-ui-test/`、gitignore 済み）を作り、最後の行に出す。テストごとの結果を1行ずつ出し、落ちたテストがあれば 1 で終わる
- 回のフォルダの `evidence/` に、xcresult、`tests.json`（テストごとの結果）、`summary.txt`、`attachments/`（テストが `attachScreenshot` で残した画面と、その名前の `manifest.json`）を写す。ログは `ui-test.log`

## 手で動かす

### 起動

```bash
run=$($S/start.sh)
$S/launch.sh "$run" signed-in previous-day            # アカウントと API の場面
$S/launch.sh "$run" signed-in meal-estimation UI_TEST_PICKED_PHOTOS=1   # 起動の値を足す
```

- `start.sh` は、この回だけのシミュレーター（`nu-tori verify-ios <回の名前>`）を作って起動し、アプリを組んで入れ、最後の行に回のフォルダ（`.scratch/verify-ios/<時刻>-sim/`）を出す。共有の iPhone（MobileBuildMCP と Xcode の既定）と UI テストの複製は使わない
- 端末は回ごとに別でも、DerivedData と xcresult は worktree の中で共有する。同じ worktree で組むもの（`start.sh`、`ui-test.sh`、`scripts/check ios`）は1つずつ回す
- `launch.sh` は、アプリを閉じてから、渡した場面で開く。アカウントと API の場面の名前は `UITestLaunch.swift` の `Account` と `API` の rawValue で、場面ごとに偽の同期サーバーが何を返すかは `ios/NuTori/UITesting/UITestLaunch+SyncScenario.swift` にある。時計は既定で `2026-10-05T06:30`（`Asia/Tokyo`）に止まる。起動の値の名前は `ios/NuToriUITests/XCUIApplication+UITestLaunch.swift` の `launched(...)` が並べている
- 記録はメモリにだけ置くので、開き直すたびに場面の始めに戻る。機能や入口を替えるときは `launch.sh` で開き直す
- MobileBuildMCP の UI の道具は既定のプロファイルの端末を叩くので、開いたら、この回の端末を名前つきのプロファイルにして選ぶ
  1. `. "$run/run.env"; echo "$UDID"` で端末の ID を読む
  2. `session_set_defaults` に `profile: "verify-ios"`、`createIfNotExists: true`、`simulatorId: <UDID>`、`bundleId: "app.nu-tori"` を渡す。`persist` は付けない（`.mobilebuildmcp/config.yaml` を書き換えない）
- 開いたと言えるのは、`launch.sh` が「開いた」を出し、プロファイルを選んだあとの `wait_for_ui` で場面の最初の画面（サインイン済みなら `timeline`、サインインしていなければ `signIn`）が出たとき

### Doctor

様子がおかしいときは、最初にこれを回す。読むだけで変えない。

```bash
$S/doctor.sh "$run"
```

この回のシミュレーターが起動しているか、アプリが入って動いているか、組んだときと今で `ios/` の中身（作業中の変更と、追跡していない新しいファイルを含む）が同じかを見る。`ios/` を変えたら、`stop.sh` で消して `start.sh` から作り直す（組み直したアプリで確かめたことを証拠に残すため）。アプリが動いていなければ `launch.sh` で開き直す。確かめたコミットは `"$run/run.env"` の `COMMIT`。

### 動かし方

起動で選んだプロファイルのまま、MobileBuildMCP の UI の道具で触る。`wait_for_ui`（`identifier` と `predicate: "exists"`）で画面を待ち、`snapshot_ui` で読んで、`tap`・`type_text`・`swipe` で触る。`type_text` は US キーボードの文字しか打てない。押す先は、地図と UI テストが使う accessibility identifier（`composer-weight`、`weight-row` など）で探す。

アプリを組む・入れる・開く道具（`build_run_sim`、`install_app_sim`、`launch_app_sim`）は使わない。起動の値が付かずに本物の開発用のサーバーへつなごうとし、サインインの画面で止まる。開くのはいつも `launch.sh`。

### 証拠を撮る

```bash
$S/shot.sh "$run" weight-recorded     # 名前は英数字とハイフン
```

`"$run/evidence/<番号>-<名前>.png"` に画面を残し、`evidence/actions.log` に、開いた場面と撮った画面を時刻つきで足す。操作の前と後の両方を撮る。

## 手元のサーバーにつないで動かす

API の境目にかかる変更（かける条件は `docs/agents/review.md` の「端末とサーバーをつなぐ確かめ」）で、アプリの API だけを `verify-server` で立てた手元のサーバーにつなぎ、端末が送った記録がサーバーの帳簿に入り、取りに行って画面に戻るまでを通す。ヘルスケア・写真・StoreKit・Apple の資格の確かめは、場面と同じ偽物のまま。

```bash
V=.agents/skills/verify-server/scripts
server=$($V/start.sh)                     # 手元のサーバー（約30秒）。start.sh と並べて回せる
$V/device.sh sign-in "$server" app        # Apple を通さずにアカウントとセッションを作る
run=$($S/start.sh)                        # 端末とアプリ（組むのに約3分）
$S/launch-local-server.sh "$run" "$server" app
```

- `launch-local-server.sh` は、`launch.sh` に、サインイン済みで初回の取得を終えていない場面（`signed-in-fetching`）と、手元のサーバーの URL と、`sign-in` で作ったセッション（`UI_TEST_SERVER_URL`・`UI_TEST_SESSION_TOKEN`・`UI_TEST_ACCOUNT_ID`）と、今の時刻（`UI_TEST_NOW`）を渡して開く。この起動の値はデバッグビルドでだけ読む（`UITestLaunch.swift` はファイルごと `#if DEBUG` で、`scripts/check ios` が見る）
- 開いたら、上の「起動」のとおりプロファイルを選ぶ。新しいアカウントなので、最初に規約への同意のシートが出る。「同意して続ける」（`agreeToTerms`）を押すと `timeline` に入る。このシートは偽の同期サーバーでは出ないので、本物につながった印になる
- 入口の通し方（体重の例。触れた記録の種類の入口に置き換える）
  1. 入力欄の「体重」（`composer-weight`）で値を記録し、`weight-row` に出るのを撮る
  2. `$V/device.sh pull "$server" app` で、帳簿に `weight_record` が `version: 1` で入り、ID が端末と同じ書き方（小文字）なのを見る
  3. `launch-local-server.sh` をもう一度回す。置き場はメモリだけなので空から始まり、`wait_for_ui` で `weight-row` がサーバーから戻るのを待って撮る
  4. 戻った記録を直し（`weight-row` → 「直す」→ 値 → 「完了」）、もう一度 `pull` して、同じ ID で `version: 2` になったのを見る。取りに行った記録を送り返す道は、端末の書き方の食い違い（#362 の大文字の ID）が出る道
- 証拠: 撮った画面（`shot.sh`）と、`"$server/evidence/requests.log"` の帳簿の記録。PR の本文に書くものは `docs/agents/review.md` の「端末とサーバーをつなぐ確かめ」
- 推定・読み分け・返事の結果まで見るなら、`verify-server` の「起動」の Anthropic の鍵を渡して立てる
- 片付けは、下の「片付け」に加えて `$V/stop.sh "$server"`

## 地図

索引は `features/README.md`、確かめる手順は機能ごとのファイルにある。

## 証拠

- `ui-test.sh` と `start.sh` の回の証拠は、回のフォルダの `evidence/` に残る（全件の回を指すときの証拠は、上の確かめ方の1）。UI テストの回は、テストごとの結果と、テストが残した画面。手で動かした回は、開いた場面と撮った画面
- 動いたと言えるのは、ユーザーの経路（画面の操作）で操作し、その結果を操作のあとの画面で読めたとき。押せたことや、シートが閉じたことだけでは足りない。記録が出るタイムラインの行、変わった値、消えたカードまで見る
- PR の本文の「確かめ」（`docs/agents/review.md` の「確かめの回し方」）に書く見えた結果は、UI テストのクラスとメソッドと結果、または開いた場面と、操作のあとに見えた画面の要素（identifier と値）。画面の添付は `docs/agents/git.md` の決まりで行う（場面の記録は作り物）

## 確かめられないとき

次は、このスキルで通せない。`docs/agents/review.md` の「確かめの回し方」で「確かめていない」と書くときに、確かめる場所をここから引く。ほかの入口を通せなかったときは、試したコマンドと、揃わなかった前提を書く。

- クラウドのセッション（Linux）ではシミュレーターが無い。アプリの画面は「確かめていない」と書き、Mac のセッションで確かめると書く。UI テストは `ios/AGENTS.md` の「確かめる」のとおり、CI の `ios-ui-test.yml` を手で回せる（全件の回）。その回が通れば、UI テストのある入口の証拠にしてよい（ランの URL と、成果物 `ios-ui-test-report` の画面）
- クラウドのセッションでは、上の「手元のサーバーにつないで動かす」も回せない。API の境目にかかる変更なら、`## 確かめ` に「端末とサーバーをつなぐ確かめは、クラウドのセッションなので確かめていない」と書き、サーバーの側を `verify-server` で確かめた結果を書く。つないだ全体は Mac のセッションか、merge のあとの TestFlight の版で確かめる
- Sign in with Apple、本物のヘルスケア、カメラ、写真を選ぶ標準の画面、通知、App Store の購入は、起動の値で差し替えるので、本物の振る舞いは実機の TestFlight の版で確かめる（`docs/agents/ios-release.md`）
- 送り待ちの置き場の移行は、前の版が書いたファイルが要る。`docs/agents/ios-mac.md` の「置き場の移行を実機で確かめる」を開発者に頼む

## 片付け

```bash
$S/stop.sh "$run"
```

この回が作ったシミュレーターだけを止めて消す。`evidence/` とログは残す。消すのはいつも `stop.sh "$run"` で、失敗して作り直すときも、そのたびに回す。MobileBuildMCP は、`session_use_defaults_profile` に `global: true` を渡して既定のプロファイルに戻す。UI テストの回（`ui-test.sh`）は端末を残さないので、片付けは要らない。
