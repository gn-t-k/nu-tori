import XCTest

/// 高さのばらつく日（短い日、画面の数倍ある日、体重だけの今日）が並んだタイムラインを、記録をキャッシュに持った状態で開く → 今日の区切りと体重の行が一番下に見える。
///
/// 並べる日を決める規則は NuToriCore の単体テスト（TimelineViewportTests の「並べる日」）が見る。
/// ここで見るのは SwiftUI の癖: 日を遅れて読む並び（LazyVStack）にすると、まだ描いていない日の高さの見積もりが実際より大きいときに、
/// 初めの位置を一番下にする指定（defaultScrollAnchor の .initialOffset の .bottom）が見積もりの端に着いて、何も描かれないまま残ること。遅れて読まない並びでは実際の下端に着く
@MainActor
final class OpenTimelineWithUnevenDaysUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "uneven-days", healthLatestKilograms: nil,
            now: .morningBeforeNotice, cacheHoldsRecords: true, timeZone: "Asia/Tokyo")
    }

    func test_開くと今日の区切りと体重の行が一番下に見えること() {
        let today = app.otherElements["day-section-2026-10-05"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilHittable(today))
        XCTAssertTrue(app.buttons["weight-row"].isHittable)
        attachScreenshot(of: app, named: "高さのばらつく日が並んだタイムラインを開いたところ")
    }
}
