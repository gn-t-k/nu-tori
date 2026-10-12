import XCTest

@MainActor
final class LaunchUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        app.launch()
    }

    func test_前面で動いていること() {
        XCTAssertEqual(app.state, .runningForeground)
        attachScreenshot(of: app, named: "起動した画面")
    }
}
