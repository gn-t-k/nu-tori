import XCTest

extension XCUIApplication {
    @MainActor static func launched(
        account: String,
        appleSignIn: String = "succeeded",
        api: String = "online",
        healthAuthorization: String = "already-requested",
        healthLatestKilograms: String?,
        healthWrite: String = "authorized",
        pickedPhotoCount: Int = 0,
        lockoutDefaults: String? = nil,
        now: UITestNow = .morningBeforeNotice,
        timeZone: String?
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_ACCOUNT"] = account
        app.launchEnvironment["UI_TEST_APPLE_SIGN_IN"] = appleSignIn
        app.launchEnvironment["UI_TEST_API"] = api
        app.launchEnvironment["UI_TEST_HEALTH_AUTHORIZATION"] = healthAuthorization
        if let healthLatestKilograms {
            app.launchEnvironment["UI_TEST_HEALTH_LATEST_KG"] = healthLatestKilograms
        }
        app.launchEnvironment["UI_TEST_HEALTH_WRITE"] = healthWrite
        // 入力欄の「写真」で、選ぶ画面を開かずに、この枚数の写真を選んだことにする
        if pickedPhotoCount > 0 {
            app.launchEnvironment["UI_TEST_PICKED_PHOTOS"] = String(pickedPhotoCount)
        }
        // 同じ名前を渡して開き直すと、前に開いたときの締め出しを覚えている
        if let lockoutDefaults {
            app.launchEnvironment["UI_TEST_LOCKOUT_DEFAULTS"] = lockoutDefaults
        }
        // アプリの時計をこの時刻（TZ のタイムゾーンの時計の時刻）で止める
        app.launchEnvironment["UI_TEST_NOW"] = now.rawValue
        if let timeZone {
            app.launchEnvironment["TZ"] = timeZone
        }
        app.launch()
        return app
    }

    /// サインイン済みで開いて 426 を受け取り、締め出されたことを lockoutDefaults に覚えさせてから閉じる
    @MainActor static func rememberLockout(in lockoutDefaults: String) {
        let app = launched(
            account: "signed-in", api: "app-build-unsupported", healthLatestKilograms: nil,
            lockoutDefaults: lockoutDefaults, timeZone: nil)
        XCTAssertTrue(app.otherElements["app-lockout"].waitForExistence(timeout: 5))
        app.terminate()
    }

    /// containing は静的なテキストごとに子孫まで問い合わせ、画面の要素が多いと探す途中で時間切れになるので、ラベルだけを見る
    @MainActor func staticText(containing text: String) -> XCUIElement {
        staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// 昨日の値から 0.2 kg 下げて記録する。初期値が 72.6 kg のとき、72.4 kg になる
    @MainActor func recordWeightTwoTenthsLower() {
        // 今日の体重が未記録なら「体重を記録」のカプセル、記録済みなら丸い「体重」
        let unrecorded = buttons["composer-weight-unrecorded"]
        (unrecorded.exists ? unrecorded : buttons["composer-weight"]).tap()
        // タイムラインの体重の知らせにも同じステッパーと「記録」があるので、シートの中を探す
        let decrease = otherElements["weight-entry-sheet"].buttons["0.1 kg 減らす"]
        XCTAssertTrue(decrease.waitForExistence(timeout: 5))
        decrease.tap()
        decrease.tap()
        weightEntryRecordButton.tap()
    }

    /// 体重のシートの「記録」。タイムラインの体重の知らせの「記録」とは別に探す
    @MainActor var weightEntryRecordButton: XCUIElement {
        navigationBars["体重"].buttons["記録"]
    }

    /// 小数点のキーは、地域の設定で「.」か「,」になる
    @MainActor func typeSeventyKilograms() {
        keys["7"].tap()
        keys["0"].tap()
        let decimal = keys["."]
        if decimal.exists {
            decimal.tap()
        } else {
            keys[","].tap()
        }
        keys["0"].tap()
    }

    @MainActor func openAccountScreen() {
        XCTAssertTrue(buttons["account"].waitForExistence(timeout: 5))
        buttons["account"].tap()
        XCTAssertTrue(otherElements["account-screen"].waitForExistence(timeout: 5))
    }

    @MainActor func confirmAccountDeletion() {
        let deleteButton = buttons["アカウントを削除"]
        // 一覧のいちばん下にあり、画面の外にあると作られないので、送って出す
        for _ in 0..<3 where !deleteButton.exists {
            swipeUp()
        }
        deleteButton.tap()
        let delete = alerts["アカウントを削除しますか？"].buttons["アカウントを削除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
    }
}
