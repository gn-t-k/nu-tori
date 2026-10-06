import XCTest

/// 今日の体重記録が無いまま、知らせの時刻（いつもの時刻が届いていなければ 8:00）を過ぎた朝に開く
@MainActor
final class WeightNoticeAfterNoticeTimeUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day", healthLatestKilograms: nil,
            now: .morningAfterNotice, timeZone: nil)
    }

    func test_タイムラインに体重の知らせが出て中で記録できること() {
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        let notice = app.otherElements["weight-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "知らせの時刻を過ぎた朝")

        notice.buttons["weight-notice-record"].tap()
        // 答えた知らせは並べないので、記録するとカードが消える
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "知らせの中で記録した")
    }
}
