import XCTest

extension XCUIApplication {
    @MainActor static func launched(
        account: String,
        appleSignIn: String = "succeeded",
        api: String = "online",
        healthAuthorization: String = "already-requested",
        healthLatestKilograms: String?,
        healthWrite: String = "authorized",
        pickedPhotos: UITestPickedPhotos? = nil,
        lockoutDefaults: String? = nil,
        now: UITestNow = .morningBeforeNotice,
        dayPassesOnReturn: Bool = false,
        cacheHoldsRecords: Bool = false,
        timeZone: String?,
        textSize: UITestTextSize? = nil,
        japaneseLocale: Bool = false,
        listingReplyLineCount: Int? = nil
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
        // 入力欄の「写真」で、選ぶ画面を開かずに、この枚数かこのファイルの写真を選んだことにし、読み終えるまでにこの秒数をかける
        if let pickedPhotos {
            switch pickedPhotos.source {
            case .solidColors(let count):
                app.launchEnvironment["UI_TEST_PICKED_PHOTOS"] = String(count)
            case .files(let files):
                app.launchEnvironment["UI_TEST_PICKED_PHOTO_FILES"] = files.joined(separator: "\n")
            }
            app.launchEnvironment["UI_TEST_PICKED_PHOTOS_LOADING_SECONDS"] = String(
                pickedPhotos.loadingSeconds)
        }
        // 見本の人の昨日の夜の返事の行の数（`ListingScene`）
        if let listingReplyLineCount {
            app.launchEnvironment["UI_TEST_LISTING_REPLY_LINE_COUNT"] = String(
                listingReplyLineCount)
        }
        // 同じ名前を渡して開き直すと、前に開いたときの締め出しを覚えている
        if let lockoutDefaults {
            app.launchEnvironment["UI_TEST_LOCKOUT_DEFAULTS"] = lockoutDefaults
        }
        // アプリの時計をこの時刻（TZ のタイムゾーンの時計の時刻）で止める
        app.launchEnvironment["UI_TEST_NOW"] = now.rawValue
        // ホームへ出てから開き直すたびに、アプリの時計を1日進める
        if dayPassesOnReturn {
            app.launchEnvironment["UI_TEST_DAY_PASSES_ON_RETURN"] = "1"
        }
        // 場面の記録を、前に開いたときに取り終えてキャッシュに持っている状態で始める
        if cacheHoldsRecords {
            app.launchEnvironment["UI_TEST_CACHE_HOLDS_RECORDS"] = "1"
        }
        if let timeZone {
            app.launchEnvironment["TZ"] = timeZone
        }
        if let textSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize.rawValue]
        }
        // 英語のランナー（CI）でも、日本の利用者と同じ日付と数の書き方にする
        if japaneseLocale {
            app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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

    /// 識別子が同じ要素（吹き出し、返事など）のうち、ラベルにこの文を含むもの
    @MainActor func element(_ identifier: String, containing text: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// 昨日の値から 0.2 kg 下げて記録する。初期値が 72.6 kg のとき、72.4 kg になる
    @MainActor func recordWeightTwoTenthsLower() {
        buttons["composer-weight"].tap()
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

    /// 体重のシートの「前回 … kg」の行
    @MainActor var weightEntryPreviousLine: XCUIElement {
        otherElements["weight-entry-sheet"].staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "前回")
        ).firstMatch
    }

    /// 体重のシートが large まで広がるのを待つ
    @MainActor func waitUntilWeightEntrySheetIsExpanded() -> Bool {
        waitUntil {
            self.navigationBars["体重"].frame.minY < self.windows.firstMatch.frame.height * 0.2
        }
    }

    /// 体重のシートが中身の高さに落ち着くのを待つ。前回の行の下の空きが少なすぎれば中身がシートの下で切れていて、多すぎれば空きが残っている
    @MainActor func waitUntilWeightEntrySheetFitsContent() -> Bool {
        waitUntil {
            let spaceBelow =
                self.windows.firstMatch.frame.maxY - self.weightEntryPreviousLine.frame.maxY
            return (20..<100).contains(spaceBelow)
        }
    }

    @MainActor private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
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
