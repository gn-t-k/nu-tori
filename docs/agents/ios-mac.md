# Mac で iOS のアプリを確かめる

- MobileBuildMCP で、変えたら `test_sim` を回し、関係する画面を開いて `screenshot` で確かめる。`test_sim` が行き先を見つけられずに失敗したら、開発者に `xcodebuild -downloadPlatform iOS`（数 GB）を頼む。computer use は、これらで確かめられないときにだけ使う
- SwiftUI プレビュー（`RenderPreview`）とビルドログ（`GetBuildLog`）は、MobileBuildMCP の `xcode_ide_call_tool` で Xcode の道具を呼ぶ。Xcode の画面は開かなくてよい。先に `XcodeOpenWorkspace` で、作業しているワークツリーの `ios/NuTori.xcodeproj` を開く。Xcode はフォルダごとに承認を求めるので、ワークツリーごとに1回、開発者に Mac で承認してもらう。Remote Control のセッションでは開発者が承認を押せないので、Xcode の道具を使わず `screenshot` で確かめる
- 整形の正は、`ios/.swift-version` の版の Linux の swift-format にする。Xcode に同梱の版と違うことがあるので、macOS では整形を確かめない

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

