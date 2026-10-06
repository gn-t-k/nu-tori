import XCTest

/// 食事を直す主な流れ。「写真」で写真を選んで推定された食事（親子丼 1杯）の食事の画面を開き、時刻を直す →
/// 料理の画面で量と名前（カツ丼）を直す → 推定し直しが届く → 料理（味噌汁）を足す → 左へ送って消す →
/// 最後の1品を消して食事が消える。API は起動の値で差し替え、料理を足す・名前を直すと、次に取りに行ったときに推定し直しを返す
@MainActor
final class EditMealUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-edit", healthLatestKilograms: nil,
            pickedPhotoCount: 1, now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
    }

    func test_食事の画面から時刻と料理を直し料理を足して消すと最後の1品で食事が消えること() {
        app.buttons["composer-photos"].tap()
        let card = app.buttons["meal-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(card, matches: "label CONTAINS %@", "親子丼"))
        card.tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))

        correctTimeToFiveThirty()
        attachScreenshot(of: app, named: "時刻を直した食事の画面")

        dish(named: "親子丼").tap()
        XCTAssertTrue(app.navigationBars["親子丼"].waitForExistence(timeout: 5))
        let quantity = app.textFields["dish-quantity"]
        replaceText(of: quantity, with: "2", length: 1)
        app.buttons["完了"].firstMatch.tap()
        let name = app.textFields["dish-name"]
        replaceText(of: name, with: "カツ丼\n", length: 3)
        XCTAssertTrue(app.navigationBars["カツ丼"].waitForExistence(timeout: 5))
        // 推定し直しは、取りに行く間隔（数秒おき）で届く。直した量は残り、材料だけが入れ替わる
        XCTAssertTrue(app.staticTexts["豚ロース"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["鶏もも肉"].exists)
        XCTAssertEqual(quantity.value as? String, "2")
        attachScreenshot(of: app, named: "推定し直したカツ丼の料理の画面")
        app.navigationBars["カツ丼"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))

        let addDish = app.buttons["meal-add-dish"]
        XCTAssertTrue(scrollUntilExists(addDish))
        addDish.tap()
        let newName = app.textFields["meal-add-dish-name"]
        XCTAssertTrue(newName.waitForExistence(timeout: 5))
        newName.tap()
        newName.typeText("味噌汁\n")
        let misoSoup = dish(named: "味噌汁")
        XCTAssertTrue(misoSoup.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(misoSoup, matches: "label CONTAINS %@", "1杯"))
        attachScreenshot(of: app, named: "料理を足した食事の画面")

        // 最後の1品でなければ、確かめずに消える
        misoSoup.swipeLeft()
        app.buttons["削除"].firstMatch.tap()
        XCTAssertTrue(misoSoup.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "meal-dish").count, 1)

        // 最後の1品は、食事ごと消すかを確かめる。「キャンセル」なら料理も残る
        let katsudon = dish(named: "カツ丼")
        katsudon.swipeLeft()
        app.buttons["削除"].firstMatch.tap()
        let cancel = app.buttons["キャンセル"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "最後の1品を消す確かめ")
        cancel.tap()
        XCTAssertTrue(katsudon.waitForExistence(timeout: 5))

        // 料理の画面の「この料理を削除」も同じ確かめで、「食事を削除」でタイムラインまで戻る
        katsudon.tap()
        XCTAssertTrue(app.navigationBars["カツ丼"].waitForExistence(timeout: 5))
        let deleteDish = app.buttons["dish-delete"]
        XCTAssertTrue(scrollUntilExists(deleteDish))
        deleteDish.tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "食事を削除", "meal-delete")
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.navigationBars["カツ丼"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["食事"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        attachScreenshot(of: app, named: "食事を消したタイムライン")
    }

    /// 止めた時計は 6:30 で、選んだ写真の時刻も 6:30。時刻のボタンから時の輪を 5 に回し、5:30 に直す
    private func correctTimeToFiveThirty() {
        let picker = app.datePickers["meal-time"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        // 日付と時刻の2つのボタンのうち、時刻
        let time = picker.buttons.element(boundBy: 1)
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        time.tap()
        let hour = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(hour.waitForExistence(timeout: 5))
        hour.adjust(toPickerWheelValue: "5")
        // 浮かんだ欄の外を押して閉じる
        app.navigationBars["食事"].tap()
        XCTAssertTrue(hour.waitForNonExistence(timeout: 5))
        XCTAssertTrue(waitUntil(time, matches: "label CONTAINS %@", "5:30"))
    }

    private func dish(named name: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "meal-dish", name)
        ).firstMatch
    }

    /// 欄の右端を押して文字の後ろに入り、今の文字を消してから打つ。名前と量の欄は右に寄せてある
    private func replaceText(of field: XCUIElement, with text: String, length: Int) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: length + 2))
        field.typeText(text)
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
}
