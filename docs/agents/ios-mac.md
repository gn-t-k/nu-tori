# Mac で iOS のアプリを確かめる

- MobileBuildMCP で、変えたら `test_sim` を回し、関係する画面を開いて `screenshot` で確かめる。`test_sim` が行き先を見つけられずに失敗したら、開発者に `xcodebuild -downloadPlatform iOS`（数 GB）を頼む。computer use は、これらで確かめられないときにだけ使う
- SwiftUI プレビュー（`RenderPreview`）とビルドログ（`GetBuildLog`）は、MobileBuildMCP の `xcode_ide_call_tool` で Xcode の道具を呼ぶ。Xcode の画面は開かなくてよい。先に `XcodeOpenWorkspace` で、作業しているワークツリーの `ios/NuTori.xcodeproj` を開く。Xcode はフォルダごとに承認を求めるので、ワークツリーごとに1回、開発者に Mac で承認してもらう。Remote Control のセッションでは開発者が承認を押せないので、Xcode の道具を使わず `screenshot` で確かめる
- UI を変えたら、状態ごとのプレビューを RenderPreview で描いて確かめる。ライトのほか、ダーク（`Color Scheme`）と最大の文字（`Dynamic Type` の `AX 5`）も `previewVariantOverrides` で描く
- 整形の正は、`ios/.swift-version` の版の Linux の swift-format にする。Xcode に同梱の版と違うことがあるので、macOS では整形を確かめない
