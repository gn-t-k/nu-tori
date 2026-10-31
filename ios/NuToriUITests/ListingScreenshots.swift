import XCTest

/// 掲載情報と LP の手順の絵に使う生の画面を、見本の場面（`ListingScene`）ごとに撮る。
///
/// ふつうの UI テストの回（`scripts/check ios-ui-test`）には入れず、`scripts/check ios-screenshots` だけが回す。
/// 撮った画面は場面の名前の添付にし、`scripts/check ios-screenshots` が xcresult から名前で取り出す。
/// 状態の表示（9:41、電波と Wi-Fi と電池が満ちた形）と、明るい表示と、文字の大きさは、`scripts/check` がシミュレーターに固める
@MainActor
final class ListingScreenshots: XCTestCase {
    func test_見本の場面の生の画面を撮ること() {
        // 1つの場面が出なくても、残りの場面は撮る
        continueAfterFailure = true
        for scene in ListingScene.allCases {
            XCTContext.runActivity(named: scene.rawValue) { _ in
                shoot(scene)
            }
        }
    }

    /// タイムラインは開くと一番下に着き、上の端（1日の丸の帯の下）にどの行が来るかは、その上に積んだ記録の高さで決まる。
    /// 昨日の夜の返事の行の数を 0 から1行ずつ増やして開き直し、上の端で行が半分隠れない数で撮る。
    /// 1行の高さは、行のあいだの空き（吹き出しやカードのあいだ、日の見出しの上下）と同じくらいなので、どこかの数で空きに当たる
    private func shoot(_ scene: ListingScene) {
        var clipped: [String] = []
        for replyLines in 0...ListingScene.maxReplyLines {
            let app = scene.launch(replyLines: replyLines)
            defer { app.terminate() }
            guard scene.prepare(app) else {
                XCTFail("\(scene.rawValue) の出るべきものが出ないので、撮らない")
                return
            }
            if scene.showsTimeline {
                do {
                    clipped = try app.elementsClippedAtTimelineTop()
                } catch {
                    XCTFail("\(scene.rawValue) のタイムラインを写せない: \(error)")
                    return
                }
            }
            // 返事の行を増やし切っても切れているときは、最後の画面を撮って落とす。どの行が何 pt 隠れたかを見て、見本の記録を直すため
            guard clipped.isEmpty || replyLines == ListingScene.maxReplyLines else { continue }
            if !clipped.isEmpty {
                XCTFail("\(scene.rawValue) の上の端で行が切れている: \(clipped.joined(separator: "、"))")
            }
            // 状態の表示も入れるため、アプリの窓でなく画面全体を撮る
            let attachment = XCTAttachment(
                uniformTypeIdentifier: "public.png", name: scene.rawValue,
                payload: XCUIScreen.main.screenshot().pngRepresentation)
            attachment.lifetime = .keepAlways
            add(attachment)
            return
        }
    }
}
