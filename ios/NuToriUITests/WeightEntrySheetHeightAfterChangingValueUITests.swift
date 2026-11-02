import XCTest

/// 値を変えたあとの体重のシートは、ドラッグで高さを切り替えられ、下げても閉じない
@MainActor
final class WeightEntrySheetHeightAfterChangingValueUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day", healthLatestKilograms: nil, timeZone: nil)
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].waitForExistence(timeout: 5))
        app.buttons["composer-weight-unrecorded"].tap()
        XCTAssertTrue(app.weightEntryPreviousLine.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        app.otherElements["weight-entry-sheet"].buttons["0.1 kg 増やす"].tap()
    }

    func test_上へ動かすと広がり下へ動かすと中身の高さに戻ること() {
        dragNavigationBar(toY: 0.1)
        XCTAssertTrue(app.waitUntilWeightEntrySheetIsExpanded())
        dragNavigationBar(toY: 0.98)
        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        attachScreenshot(of: app, named: "広げてから中身の高さに戻した体重のシート")
    }

    func test_中身の高さから下へ動かしても閉じないこと() {
        dragNavigationBar(toY: 0.98)
        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        attachScreenshot(of: app, named: "値を変えたあとに下げても閉じない体重のシート")
    }

    /// ナビゲーションバーをつかんで、画面の高さのこの割合の位置まで動かす
    private func dragNavigationBar(toY: CGFloat) {
        app.navigationBars["体重"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(
                forDuration: 0.1,
                thenDragTo: app.windows.firstMatch.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: toY)))
    }
}
