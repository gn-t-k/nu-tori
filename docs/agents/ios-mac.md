# Mac で iOS のアプリを確かめる

- MobileBuildMCP で、変えたら `test_sim` を回し、関係する画面を開いて `screenshot` で確かめる。`test_sim` が行き先を見つけられずに失敗したら、開発者に `xcodebuild -downloadPlatform iOS`（数 GB）を頼む。computer use は、これらで確かめられないときにだけ使う
- UI を変えたら、状態ごとのプレビューを、ライトのほか、ダークと最大の文字（AX5）でも描いて確かめる。`scripts/preview-sheet` で並べて描く（下の「プレビューを並べて確かめる」）
- Mac のシェルは zsh で、合うファイルの無いグロブは「no matches found」で止まる。`grep --include='*.swift'` のように、グロブは引用符で囲む
- ディスクが溜まったら、`scripts/clean-builds` を回す。引数なしで、元の worktree が無い DerivedData と MobileBuildMCP の置き場、済んだ worktree を並べ、`--delete` で前の2つを消す。済んだ worktree は消さないので、並んだものを見て消すかを決める。`scripts/check` と MobileBuildMCP のビルドは worktree の中の `ios/.build/DerivedData` に置き、worktree と一緒に消えるので、並ぶ DerivedData は Xcode の道具（下の「Xcode の道具」）が作ったもの
- `scripts/check` と MobileBuildMCP は同じ DerivedData を使うので、同じ worktree で同時に回すと、あとから始めたほうが `build.db: database is locked` で落ちる。終わってからやり直す
- `ios` の中を探すときは、`rg` か Grep の道具を使う。どちらも `.gitignore` で Swift のビルド生成物（`.build/`）を飛ばし、`.gitignore` を読まないときもリポジトリ直下の `.ignore` で飛ばす。`grep -r` は生成物まで読み、120 秒を超えた
- 整形の正は、`ios/.swift-version` の版の Linux の swift-format にする。Xcode に同梱の版と違うことがあるので、macOS では整形を確かめない

## プレビューを並べて確かめる

`scripts/preview-sheet <プレビューのファイル>` は、下の「Xcode の道具」の2〜5を自分で済ませ、プレビューの状態ごとに、ライト・ダーク・AX5 を横に並べた画像を作る。使い方は引数なしで出る。初めて開くワークツリーでは、「Xcode の道具」の2のとおり、開発者に Mac で承認してもらう。

- 読むのは並べた画像から始める。同じ行のライト・ダーク・AX5 で、行や部品の形がそろっているかを見比べる。個々の画像は、並べた画像で怪しいものだけ開く
- 状態の多い画面や、いくつもの画面を見回るときは、サブエージェントに渡し、崩れていた状態と、その個々の画像のパスだけを返してもらう
- シミュレータで撮った画面（`screenshot`）を見比べるときは、`scripts/tile-images` で並べる。使い方は引数なしで出る

**Why:** 画面を確かめるセッションが、スクリーンショットを数十枚読んで文脈が 400K 前後まで膨らみ、写っていた崩れ（日のまとめのタンパク質の行だけ縦）を見落とした。並べるスクリプトもセッションごとに作り直していた（#562）

## Xcode の道具

SwiftUI プレビュー（`RenderPreview`）やビルドログ（`GetBuildLog`）のような Xcode の道具は、MobileBuildMCP の中継で呼ぶ。Xcode は画面を出さない `Xcode Service` のプロセスで動き、Mac の上のセッションすべてで1つを分け合う。

道具の一覧に `xcode_tools_<名前>`（`xcode_tools_RenderPreview` など）があれば、それを呼ぶ。中身をそのまま返す。無ければ `xcode_ide_call_tool` の `remoteTool` に名前を渡す。こちらは中身が `content: []` で返るので、返った `rawResponseJsonPath` のファイルの `response` を読む。

1. `XcodeListWorkspaces` で、作業しているワークツリーの `ios/NuTori.xcodeproj` が開いているか見る。開いていれば、その `workspaceIdentifier` で3へ進む
2. `XcodeOpenWorkspace` に、ワークツリーの `ios/NuTori.xcodeproj` の絶対パスを渡す。返る `workspaceIdentifier` を、以後の道具すべてに渡す。ID は開き直すたびに変わる。Xcode はフォルダごとに承認を求めるので、ワークツリーごとに1回、開発者に Mac で承認してもらう。Remote Control のセッションでは開発者が承認を押せないので、Xcode の道具を使わず `screenshot` で確かめる
3. 行き先（`XcodeOpenWorkspace` が返す `activeRunDestination`、または `XcodeListRunDestinations`）が `nu-tori ui-test-base`（UI テストの複製の元）なら、`XcodeSwitchRunDestination` で `.mobilebuildmcp/config.yaml` の `simulatorName` の端末に替える。開き直すと戻ることがある
4. `BuildProject` を1回呼ぶ。ビルドが終わるまで返らないので、パッケージの読み込みもこれで待てる。新しいワークツリーで先に `RenderPreview` を呼ぶと、「Waiting for packages to load」で止まる
5. `RenderPreview` を呼ぶ。`sourceFilePath` は Xcode のプロジェクトの中のパスで、`NuTori/NuTori/Goal/GoalDecidedCard+Previews.swift` のようにプロジェクトの名前から書く。描いた画像は、返った `previewSnapshotPath` を Read で読む

### ファイルを足す

- すでにあるフォルダには、シェルや Write で足してよい。Xcode Service がすぐ拾う
- 新しいフォルダは、親のフォルダを `XcodeLS` で一度読んでから、`XcodeMakeDir` で作る。中のファイルはシェルや Write で書いてよい。シェルで作ったフォルダは、開き直しても Xcode Service が拾わない。`XcodeWrite` で Xcode の知らないフォルダに書くと、`<フォルダ> 2` という別のフォルダができる
- 足したファイルを Xcode Service が拾っていないと、`RenderPreview` が「File not found in project structure」で落ちる。`XcodeListWorkspaces` でほかのワークツリーが開いていないことを確かめてから、`pkill -x 'Xcode Service'` で止め、2から開き直す。ほかのワークツリーが開いていたら、止めるとそのセッションの道具も切れるので、開発者に聞く

### `project.pbxproj` が書き換わったら

Xcode は開いたときに、`project.pbxproj` を自分の書き方に直すことがある。自分で変えていないのに書き換わったら、差分を読み、`scripts/check ios` が通ることを確かめてから、作業とは別のコミットで取り込む。戻すと、開くたびにまた書き換わる

## UI テストのシミュレータ

`scripts/check ios-ui-test` は、回すたびにシミュレータの複製（`nu-tori ui-test <pid>`）を作り、終わったら消す。ほかのワークツリーや本体のチェックアウトで同時に回しても、別の端末で動くのでぶつからない。

- 複製の元（`nu-tori ui-test-base`）は、初めて回したときに作られて残る（数百 MB）。UI テストを回すたびに落とされるので、Xcode・Simulator.app・MobileBuildMCP で選ばない。要らなくなったら、UI テストが回っていないときに `xcrun simctl delete <UDID>` で消す。次に回したときに作り直される
- kill -9 などで止めると、複製が残る。次に回したときに、名前の pid のプロセスが居なければ消える
- 落ちた UI テストを追うときは、`scripts/check ios-ui-test --only <クラス>[/<メソッド>] --repeat <回数>` で、そのテストだけを落ちるまでくり返す
- MobileBuildMCP と Xcode は、今までどおり共有の iPhone を使う。`scripts/check` とはぶつからないが、MobileBuildMCP や Xcode どうしでは同じ端末を取り合う

## 置き場の移行を実機で確かめる

送り待ちの置き場の形を変えた PR は、merge の前に、前の版が書いた本物のファイルから移せることを開発者に実機で確かめてもらう。移行の手順そのものはテストで確かめ、ここでは本物のファイルで動くことだけを見る。開発者に頼むときは、次の手順をそのまま渡す。

1. iPhone に TestFlight の版があれば、電波のある所で一度開いて送り待ちを送ってから消す。TestFlight の版は本番に、Xcode から入れる版は開発用のサーバーにつながるので、混ぜない
2. main を Xcode で iPhone に入れ（scheme `NuTori`、ケーブルでつなぐ）、サインインし、電波のある状態で体重を1件記録する
3. 機内モードにして、体重を1件記録し、2の記録を直す。値は見分けやすいものにする
4. アプリを閉じる。機内モードのままにする（前の版は、閉じていても電波が戻ると裏で同期する）
5. PR のブランチを、アプリを消さずに Xcode で入れる。「Replace」は押してよい。機内モードでは証明書を確かめられず「Developer App Certificate is not trusted」で起動が止まるが、入れることはできている
6. 機内モードを切り、ホーム画面からアプリを開く。落ちずに開き、3の記録と直した値が出ること
7. アプリを消して入れ直し、サインインする。サーバーから取り直したタイムラインに、3の記録と直した値が出ること

PR の本文の「確かめる項目」に結果を書く。記録の値は開発者の健康データなので書かない。

