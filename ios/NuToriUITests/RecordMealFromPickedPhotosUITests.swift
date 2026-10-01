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
            pickedPhotoCount: 1, timeZone: Self.timeZoneIdentifier)
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
    }

    func test_選んだ写真の食事が推定され食事の画面から消せること() {
        app.buttons["composer-photos"].tap()

        let card = app.buttons["meal-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(element(containing: "親子丼").waitForExistence(timeout: 30))
        XCTAssertTrue(element(containing: "464 kcal").exists)
        XCTAssertTrue(waitUntil(todayRing, matches: "value CONTAINS %@", "食事の記録あり"))
        attachScreenshot(of: app, named: "推定された食事のカード")

        card.tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "鶏もも肉").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "栄養の出どころ: 成分表").exists)
        XCTAssertTrue(app.buttons["nutrient-citation"].exists)
        attachScreenshot(of: app, named: "食事の画面")

        app.buttons["meal-delete"].tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "食事を削除", "meal-delete")
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "食事を削除する確かめ")
        confirm.tap()

        XCTAssertTrue(app.navigationBars["食事"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCTAssertTrue(waitUntil(todayRing, matches: "NOT (value CONTAINS %@)", "食事の記録あり"))
        attachScreenshot(of: app, named: "食事を消したタイムライン")
    }

    private static let timeZoneIdentifier = "Asia/Tokyo"

    private var todayRing: XCUIElement {
        app.buttons["ring-\(todayIdentifier)"]
    }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
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
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
        let parts = calendar.dateComponents([.year, .month, .day], from: .now)
        return String(
            format: "%04d-%02d-%02d", try XCTUnwrap(parts.year), try XCTUnwrap(parts.month),
            try XCTUnwrap(parts.day))
    }
}
