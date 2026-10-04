import XCTest

/// 「写真」で写真を選ぶ → カードが出る → 推定の結果が届く → 食事の画面を開く → 食事を削除する。
/// 写真の選択は起動の値で差し替え（選ぶ画面を開かずに1枚選んだことにする）、API は最初に取りに行くと推定中、
/// 次からは推定できた（親子丼。鶏もも肉 80 g・ご飯 200 g で 464 kcal）を返す
@MainActor
final class RecordMealFromPickedPhotosUITests: XCTestCase {
    private var app = XCUIApplication()
    private var todayIdentifier = ""

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        todayIdentifier = try Self.todayIdentifier()
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: nil,
            pickedPhotoCount: 1, now: Self.now, timeZone: Self.timeZoneIdentifier)
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
    }

    func test_選んだ写真の食事が推定され食事の画面から消せること() {
        app.buttons["composer-photos"].tap()

        let card = app.buttons["meal-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(element(containing: "親子丼").waitForExistence(timeout: 30))
        XCTAssertTrue(waitUntil(todayRing, matches: "value CONTAINS %@", "食事の記録あり"))
        attachScreenshot(of: app, named: "推定された食事のカード")

        card.tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "鶏もも肉").waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "食事の画面")
        let delete = app.buttons["meal-delete"]
        XCTAssertTrue(scrollUntilExists(delete))
        XCTAssertTrue(app.buttons["nutrient-citation"].exists)
        attachScreenshot(of: app, named: "食事の画面の下")

        delete.tap()
        let confirm = app.buttons["meal-delete-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "食事を削除する確かめ")
        confirm.tap()

        XCTAssertTrue(app.navigationBars["食事"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCTAssertTrue(waitUntil(todayRing, matches: "NOT (value CONTAINS %@)", "食事の記録あり"))
        attachScreenshot(of: app, named: "食事を消したタイムライン")
    }

    private static let now = UITestNow.morningBeforeNotice
    private static let timeZoneIdentifier = "Asia/Tokyo"

    private var todayRing: XCUIElement {
        app.buttons["ring-\(todayIdentifier)"]
    }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    /// 食事の画面は List なので、画面の外の行はまだ作られていない。下へ送って作らせる
    private func scrollUntilExists(_ element: XCUIElement) -> Bool {
        for _ in 0..<5 where !element.exists {
            app.swipeUp()
        }
        return element.exists
    }

    /// 推定の結果は、取りに行く間隔（数秒おき）で届く
    private func waitUntil(_ element: XCUIElement, matches format: String, _ argument: String)
        -> Bool
    {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format, argument), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 30) == .completed
    }

    private static func todayIdentifier() throws -> String {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents(
            [.year, .month, .day],
            from: try now.date(in: timeZone))
        return String(
            format: "%04d-%02d-%02d", try XCTUnwrap(parts.year), try XCTUnwrap(parts.month),
            try XCTUnwrap(parts.day))
    }
}
