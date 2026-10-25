import XCTest

/// 「写真」で写真を選んでから、読み終えて食事のカードが出るまで、タイムラインの一番下に仮のカードを出す（#752）。
/// 写真の選択は起動の値で差し替え（選ぶ画面を開かずに3枚選んだことにし、読み終えるまで3秒かける）
@MainActor
final class ShowPickedPhotosLoadingUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: nil,
            pickedPhotos: UITestPickedPhotos(count: 3, loadingSeconds: 3), timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
    }

    func test_写真を読んでいるあいだ仮のカードを出し食事のカードが出たら外すこと() {
        app.buttons["composer-photos"].tap()

        let loading = app.descendants(matching: .any)["picked-photos-loading"]
        XCTAssertTrue(loading.waitForExistence(timeout: 2))
        XCTAssertTrue(loading.label.contains("3枚"))
        XCTAssertFalse(app.buttons["meal-card"].exists)
        attachScreenshot(of: app, named: "写真を読んでいるあいだの仮のカード")

        XCTAssertTrue(app.buttons["meal-card"].waitForExistence(timeout: 10))
        XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
        attachScreenshot(of: app, named: "仮のカードが食事のカードに替わったタイムライン")
    }
}
