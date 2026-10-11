import XCTest

/// かなのキーボードでひらがなを確定してから送ると、書く欄が空に戻る。
/// 条件は、サインイン済みで、シミュレータがかなのキーボードを出し（`scripts/check` がそろえる）、書く欄にカーソルがある。
/// `typeText` はキーボードを通さずに文字を入れるので、キーを押して打つ
@MainActor
final class SendConfirmedKanaTextUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "conversation", healthLatestKilograms: nil,
            now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.composerField.waitForExistence(timeout: 5))
        app.composerField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(key("は").waitForExistence(timeout: 5), "かなのキーボードが出ていない")
    }

    func test_ひらがなを確定してから送ると書く欄が空に戻ること() {
        key("は").tap()
        key("な").tap()
        // 打っているあいだの改行のキーは「確定」で、ひらがなのまま確定する
        app.keyboards.buttons["Return"].tap()
        app.buttons["composer-send"].tap()
        XCTAssertTrue(
            app.element("sent-text-bubble", containing: "はな").waitForExistence(timeout: 5))
        // 空の書く欄は、値として欄の案内の文を返す
        XCTAssertTrue(waitUntil(app.composerField, matches: "value == %@", "書く"))
        attachScreenshot(of: app, named: "確定したひらがなを送ったあとの書く欄")
    }

    /// 空にする前に最後の1文字を消す直し方では、1文字の文だけ欄に残る
    func test_1文字のひらがなを確定してから送っても書く欄が空に戻ること() {
        key("は").tap()
        app.keyboards.buttons["Return"].tap()
        app.buttons["composer-send"].tap()
        XCTAssertTrue(app.element("sent-text-bubble", containing: "は").waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(app.composerField, matches: "value == %@", "書く"))
        attachScreenshot(of: app, named: "確定した1文字のひらがなを送ったあとの書く欄")
    }

    private func key(_ label: String) -> XCUIElement {
        app.keyboards.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", label)
        ).firstMatch
    }
}
