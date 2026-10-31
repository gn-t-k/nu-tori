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
                let app = scene.launch()
                defer { app.terminate() }
                guard scene.prepare(app) else {
                    XCTFail("\(scene.rawValue) の出るべきものが出ないので、撮らない")
                    return
                }
                // 上の端で行が切れていても撮る。見本の記録を直すとき、切れた画面と、どの行が何 pt 隠れたかを見比べるため
                if scene.showsTimeline {
                    do {
                        let clipped = try app.elementsClippedAtTimelineTop()
                        if !clipped.isEmpty {
                            XCTFail(
                                "\(scene.rawValue) の上の端で行が切れている: \(clipped.joined(separator: "、"))")
                        }
                    } catch {
                        XCTFail("\(scene.rawValue) のタイムラインを写せない: \(error)")
                    }
                }
                // 状態の表示も入れるため、アプリの窓でなく画面全体を撮る
                let attachment = XCTAttachment(
                    uniformTypeIdentifier: "public.png", name: scene.rawValue,
                    payload: XCUIScreen.main.screenshot().pngRepresentation)
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
