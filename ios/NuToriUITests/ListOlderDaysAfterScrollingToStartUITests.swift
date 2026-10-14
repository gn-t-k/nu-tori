import XCTest

/// 開いたときに並べる分より長いタイムラインを、並べたいちばん古い日の上端まで遡って止める → その前の日が足され、見ていた所からは動かない。
///
/// 上端で止めたら古い日を足し、見ていた日を上端に置き直すと決める規則は NuToriCore の単体テスト（TimelineViewportTests の「並べる日」）が見る。
/// ここで見るのは SwiftUI の癖: 上端にいるかがスクロールの位置（onScrollGeometryChange）から届くこと、
/// 上に日を足すと中身が下へずれるが、足した更新のあとの ScrollViewProxy の scrollTo で、見ていた日が上端に戻ること
@MainActor
final class ListOlderDaysAfterScrollingToStartUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "day-ring", healthLatestKilograms: nil,
            now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
    }

    func test_上端まで遡って止めると前の日が足されて見ていた所から動かないこと() {
        // 使い始めた日（21日前）
        let started = app.otherElements["day-section-2026-09-14"]
        XCTAssertFalse(started.exists)

        let timeline = app.otherElements["timeline"]
        for _ in 0..<10 where !started.exists {
            timeline.swipeDown()
        }

        XCTAssertTrue(started.waitForExistence(timeout: 5))
        // 開いたときに並べたいちばん古い日（14日前。今日と明日の2件に、1日2件ずつ足して項目が30個たまる日）
        XCTAssertTrue(waitUntilHittable(app.otherElements["day-section-2026-09-21"]))
        XCTAssertTrue(app.navigationBars.staticTexts["9月21日（月）"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "上端まで遡って前の日が足されたタイムライン")
    }
}
