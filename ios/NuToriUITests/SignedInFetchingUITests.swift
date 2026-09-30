import XCTest

@MainActor
final class SignedInFetchingUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in-fetching", timeZone: nil)
    }

    func test_タイムラインの場所に読み込み中を出すこと() {
        XCTAssertTrue(app.staticTexts["記録を読み込んでいます…"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["day-ring-strip"].exists)
        let rings = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "ring-"))
        XCTAssertEqual(rings.count, 7)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "ring-")).count, 0)
        XCTAssertFalse(app.otherElements["signIn"].exists)
        attachScreenshot(of: app, named: "初回の取得のあいだのタイムライン")
    }
}
