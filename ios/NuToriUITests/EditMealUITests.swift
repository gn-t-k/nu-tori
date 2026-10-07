import XCTest

/// 食事を直す主な流れ。「写真」で写真を選び、推定中の食事の画面を開く（料理を足せない）→ 推定が届く（親子丼 1杯）→ 時刻を直す →
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
        // 推定が終わる前に開く（偽のサーバーは、推定を3回めの取得まで終えない）
        card.tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))

        // 推定を待っているあいだは、「料理を足す」の代わりに待ちの1行を置き、時刻と「食事を削除」は出す
        let addDishWait = app.staticTexts["meal-add-dish-wait"]
        XCTAssertTrue(addDishWait.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["meal-add-dish"].exists)
        XCTAssertTrue(app.datePickers["meal-time"].exists)
        XCTAssertTrue(app.scrollUntilExists(app.buttons["meal-delete"]))
        attachScreenshot(of: app, named: "推定中の食事の画面")
        // 推定が終わると、開き直さなくても料理が届き、待ちの1行が消える
        XCTAssertTrue(dish(named: "親子丼").waitForExistence(timeout: 30))
        XCTAssertTrue(addDishWait.waitForNonExistence(timeout: 5))
        // 「食事を削除」を探して下へ送っていたら、時刻を直すために上へ戻す
        app.swipeDown()

        correctTimeToFiveThirty()
        attachScreenshot(of: app, named: "時刻を直した食事の画面")

        dish(named: "親子丼").tap()
        XCTAssertTrue(app.navigationBars["親子丼"].waitForExistence(timeout: 5))
        let quantity = app.textFields["dish-quantity"]
        // 量の欄は、右端を押しても文字の前に入ることがある（iOS 26.5）ので、2度押して数を選んでから打つ
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        quantity.doubleTap()
        quantity.typeText("2")
        app.buttons["完了"].firstMatch.tap()
        // 名前は打ったまま確定せずに「‹ 食事」で戻っても、送られて料理の行の名前が変わる
        let name = app.textFields["dish-name"]
        replaceText(of: name, with: "カツ丼", length: 3)
        app.navigationBars["親子丼"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))
        XCTAssertTrue(dish(named: "カツ丼").waitForExistence(timeout: 5))
        dish(named: "カツ丼").tap()
        XCTAssertTrue(app.navigationBars["カツ丼"].waitForExistence(timeout: 5))
        // 推定し直しは、取りに行く間隔（数秒おき）で届く。直した量は残り、材料だけが入れ替わる
        XCTAssertTrue(app.staticTexts["豚ロース"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["鶏もも肉"].exists)
        XCTAssertEqual(quantity.value as? String, "2")
        attachScreenshot(of: app, named: "推定し直したカツ丼の料理の画面")
        app.navigationBars["カツ丼"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))

        let addDish = app.buttons["meal-add-dish"]
        XCTAssertTrue(app.scrollUntilExists(addDish))
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
        XCTAssertTrue(app.mealDeletionConfirm.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "最後の1品を消す確かめ")
        cancelConfirmation()
        XCTAssertTrue(app.mealDeletionConfirm.waitForNonExistence(timeout: 5))
        XCTAssertTrue(katsudon.waitForExistence(timeout: 5))

        // 料理の画面の「この料理を削除」も同じ確かめで、「食事を削除」でタイムラインまで戻る
        katsudon.tap()
        XCTAssertTrue(app.navigationBars["カツ丼"].waitForExistence(timeout: 5))
        let deleteDish = app.buttons["dish-delete"]
        XCTAssertTrue(app.scrollUntilExists(deleteDish))
        deleteDish.tap()
        XCTAssertTrue(app.mealDeletionConfirm.waitForExistence(timeout: 5))
        app.mealDeletionConfirm.tap()

        XCTAssertTrue(app.navigationBars["カツ丼"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["食事"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        attachScreenshot(of: app, named: "食事を消したタイムライン")
    }

    /// 止めた時計は 6:30 で、選んだ写真の時刻も 6:30。時刻のボタンから時の輪を 5 に回し、5:30 に直す
    private func correctTimeToFiveThirty() {
        let picker = app.datePickers["meal-time"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        // 日付と時刻の2つのボタンのうち、時刻。並びの番号では日付のボタン（10/5/26）に当たり暦が開いたので、時刻の「:」で見分ける
        let time = picker.buttons.matching(NSPredicate(format: "label CONTAINS %@", ":")).firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        time.tap()
        // 輪の並びは言語で変わる（日本語は午前・午後の輪が先）ので、並びの番号でなく今の時（6）の輪を探す
        let hour = app.pickerWheels.matching(NSPredicate(format: "value BEGINSWITH %@", "6"))
            .firstMatch
        XCTAssertTrue(hour.waitForExistence(timeout: 5))
        hour.adjust(toPickerWheelValue: "5")
        // 浮かんだ欄の外を押して閉じる。回した時の輪は値が変わり上の問い合わせで見つからなくなるので、輪のどれかで見る
        app.navigationBars["食事"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(waitUntil(time, matches: "label CONTAINS %@", "5:30"))
    }

    /// 確かめを「キャンセル」で閉じる。iOS 26 の確かめは押した場所から浮かぶ欄で出て「キャンセル」のボタンを持たず、
    /// 欄の外を押すのがキャンセルになる（CI の要素の木では「ポップアップを閉じる」の領域だけがある）。
    /// 画面の下から出る形なら「キャンセル」を押す
    private func cancelConfirmation() {
        let cancel = app.buttons["キャンセル"]
        if cancel.exists {
            cancel.tap()
        } else {
            // 欄は押した料理の行のそばに浮かび、画面の真ん中に重なることがある。領域の真ん中を押すと欄のボタンに当たりうるので、
            // 行から離れた上の端（ナビゲーションバーのあたり）を押す
            app.otherElements["PopoverDismissRegion"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
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
}
