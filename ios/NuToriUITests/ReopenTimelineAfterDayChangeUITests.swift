import XCTest

/// 食事の多い日が続いたタイムラインの一番下を見たまま、ホームへ出て、日付が変わってから開き直す → 足された今日の区切りが一番下に見える。
/// 足された日の高さは、描かれるまでほかの日の平均で見積もられる。食事の多い日が続くと見積もりが画面より大きくなり、その端へ動くと何も描かれないまま残る
///
/// 足された日が描かれるのを待ってから下端へ動かすと決める規則は NuToriCore の単体テスト（TimelineViewportTests の「過去の不具合の場面」の、日付が変わって開き直す場面）が見る。
/// ここで見るのは SwiftUI の癖: 遅れて読む並び（LazyVStack）の、まだ描いていない日の高さの見積もりと、
/// いちばん新しい日の onChange が、足された日が今の位置のすぐ下に描かれてから届くこと（描かれる前に動かすと、見積もりの端に着く）
@MainActor
final class ReopenTimelineAfterDayChangeUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: nil,
            pickedPhotoCount: 1, now: .morningBeforeNotice, dayPassesOnReturn: true,
            timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
        // 使い始めた日（10月5日）を空のままにして、10月6日と7日に食事を並べる
        reopenOnNextDay(titled: "10月6日（火）")
        recordMealsFillingScreens(on: "2026-10-06")
        reopenOnNextDay(titled: "10月7日（水）")
        recordMealsFillingScreens(on: "2026-10-07")
    }

    func test_日付が変わってから開き直すと今日の区切りが一番下に見えること() {
        reopenOnNextDay(titled: "10月8日（木）")

        let today = app.otherElements["day-section-2026-10-08"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilHittable(today))
        attachScreenshot(of: app, named: "日付が変わってから開き直したタイムライン")
    }

    /// 1日ぶんが画面の高さの数倍になる数
    private static let mealsPerDay = 7

    private func recordMealsFillingScreens(on day: String) {
        // 画面の外へ流れたカードは要素の木から外れて数えられないので、足されたのを日の区切りの高さで待つ
        let section = app.otherElements["day-section-\(day)"]
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        // 食事のカード1枚ぶんより小さい高さ。推定の結果が届いて伸びる分（数十ポイント）とは見分けられる
        let cardMinHeight: CGFloat = 200
        for _ in 0..<Self.mealsPerDay {
            let height = section.frame.height
            app.buttons["composer-photos"].tap()
            XCTAssertTrue(waitUntil { section.frame.height > height + cardMinHeight })
        }
        // 足された日の見積もりが画面より大きくなるだけ、1日が長い
        XCTAssertGreaterThan(section.frame.height, app.frame.height * 2)
        // 一番下を見ている状態にする
        app.otherElements["timeline"].swipeUp()
        let cards = app.buttons.matching(identifier: "meal-card")
        let count = cards.count
        XCTAssertGreaterThan(count, 0)
        XCTAssertTrue(waitUntilHittable(cards.element(boundBy: count - 1)))
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in MainActor.assumeIsolated(condition) }, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    /// 開き直すと、題が次の日になる。入力欄の形が変わる（今日の体重が未記録になる）ので、変わり終えるのを題で待つ
    private func reopenOnNextDay(titled title: String) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
    }
}
