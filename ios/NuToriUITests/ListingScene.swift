import XCTest

/// 見本の場面と、撮る生の画面の対応。掲載情報と LP の手順の絵の生の画面は、ここに並べた場面だけを撮る（`ListingScreenshots`）。
///
/// 名前（rawValue）は合成のコマンドとの約束で、生の画面のファイル名（`step-weigh.png`）になる。
/// 場面を足すときは case を足し、`launch()` と `prepare(_:)` に書く。見本の記録は作り物だけにし、値は LP の見本とそろえる（`ios/AGENTS.md` の「見本の場面」）
enum ListingScene: String, CaseIterable {
    /// 朝、まだ量っていない体重を、タイムラインの体重の知らせのステッパーで 77.8 kg に合わせたところ（LP の手順1）
    case stepWeigh = "step-weigh"
    /// 食べる前に撮った写真が、推定を待ちながらタイムラインに並んだところ（LP の手順2）
    case stepPhoto = "step-photo"
    /// 毎週の見直しで1日の目安が変わった知らせ（LP の手順3）
    case stepGuide = "step-guide"
    /// 撮った食事が推定されて、料理と kcal が出たタイムライン
    case photoEstimated = "photo-estimated"
    /// 撮り忘れて書いた食事が推定されたところ
    case textMeal = "text-meal"
    /// 推定された料理の材料と量と、主な栄養。カレーライスの料理の画面（食事の画面の料理の行から潜った先）
    case dish = "dish"
    /// 週の見直しと目標の経過。目標の画面（体重の傾向、見直しで変わった1日の目安、週の振り返りへの1行）
    case weeklyReview = "weekly-review"

    /// 場面の記録と時計で開く。記録は、アプリの UI テストの差し替えの見本の人（`UITestLaunch.listingSampleScenario(_:)`）。
    /// アプリの時計は、撮る画面の状態の表示（9:41）とそろえ、タイムゾーンは日本に固める。
    /// `stepGuide` だけ例外で、月曜の 6:30 にする。1日の目安が変わった知らせと週の振り返りのカードは見直した月曜の日に置くので、水曜には火曜と水曜の記録の上へ流れて見えない。
    /// 9:41 だと今朝 7:00 の体重が知らせの下に写るので、その前の朝にして、見せたい知らせをタイムラインの一番下にする。状態の表示は 9:41 のままで、時刻のずれは画面に出ない
    @MainActor func launch() -> XCUIApplication {
        switch self {
        case .stepWeigh:
            // 今朝の体重がまだ無く、体重の知らせの時刻（8:00）を過ぎた朝
            open(api: "listing-sample-before-weighing")
        case .weeklyReview:
            open(api: "listing-sample")
        case .stepGuide:
            open(api: "listing-sample-before-weighing", now: .listingSampleMondayBeforeWeighing)
        case .stepPhoto:
            // 写真は LP の見本と同じ Wikimedia Commons の CC0（Ocdp）のおにぎりで、nu-tori の利用者の食事ではない。
            // 出どころは site/src/pages/landing-a/example-photo-meals.ts。リポジトリに2つ置かないよう、LP の写真をそのまま読む
            open(api: "listing-sample", photo: "onigiri")
        case .photoEstimated, .dish:
            // 写真は LP の「撮るだけ」の節と昼ごはんの日の見本のカレーライス（出どころは stepPhoto と同じ）。推定の結果も LP の見本と同じ料理・材料・量
            open(api: "listing-sample-photo-estimated", photo: "curry")
        case .textMeal:
            open(api: "listing-sample-text-meal")
        }
    }

    /// 昨日の夜の返事の形の番号（アプリの `ListingSample.feedback(on:shape:)`。行の数の2倍と、前置きを置かないなら1）。
    /// タイムラインは開くと一番下に着き、上の端（1日の丸の帯の下）にどの行が来るかは、その上に積んだ記録の高さで決まる。
    /// 上の端で吹き出しやカードが半分切れないよう、場面ごとに iPhone 18 Pro Max のシミュレーターで撮り比べて選んだ（#858）。
    /// textMeal はどの形でも少し切れるので、見出しが読める形にした。画面が変わって切れたら選び直す（テストでは確かめない）
    private var replyShape: Int {
        switch self {
        case .textMeal: 16
        case .stepWeigh, .photoEstimated: 10
        case .stepPhoto, .stepGuide: 4
        case .dish, .weeklyReview: 0
        }
    }

    /// 撮る前の操作をし、出るべきものが出るまで待つ。出なければ false（空の画面や読み込み中を撮らない）
    @MainActor func prepare(_ app: XCUIApplication) -> Bool {
        switch self {
        case .stepWeigh:
            return Self.stepWeight(in: app.otherElements["weight-notice"], app: app)
        case .stepPhoto:
            // 送り終えて推定中が届くと、カードの状態の1行が出る。この場面の偽のサーバーは推定を終えない
            return Self.pickPhoto(app, until: "推定しています…")
        case .stepGuide:
            // 今日の 0:05 の見直しで、1日の目安が 1,900 kcal から 1,750 kcal に変わった（daily-guide-example.json の reviews の2つめ）
            let changed =
                app.descendants(matching: .any)["daily-guide-change-notice"]
                .waitForExistence(timeout: 10)
                && app.buttons["weekly-review-card"].exists
            // 知らせが一番下にある。今朝 7:00 の体重（77.7 kg）も、体重の知らせのカードも、その下に出ていない
            return changed && !app.staticText(containing: "77.7 kg").exists
                && !app.otherElements["weight-notice"].exists
        case .photoEstimated:
            // 推定が届くと、カードの名前の場所が料理の名前になる
            return Self.pickPhoto(app, until: "カレーライス")
        case .dish:
            guard Self.pickPhoto(app, until: "カレーライス") else { return false }
            Self.todaysPhotoMealCard(app).tap()
            guard app.navigationBars["食事"].waitForExistence(timeout: 5) else { return false }
            let curry = app.buttons.matching(
                NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "meal-dish", "カレーライス")
            ).firstMatch
            guard curry.waitForExistence(timeout: 5) else { return false }
            curry.tap()
            guard app.navigationBars["カレーライス"].waitForExistence(timeout: 5) else { return false }
            // 材料の量の欄（ごはん・牛肉・じゃがいも…の行）が出てから撮る
            guard app.textFields["dish-ingredient-quantity"].firstMatch.waitForExistence(timeout: 5)
            else { return false }
            // プッシュで潜る動きが終わるまで少し待つ
            Thread.sleep(forTimeInterval: 1)
            return true
        case .weeklyReview:
            guard Self.waitForTodaysWeight(app) else { return false }
            let goalLink = app.buttons["goal-link"]
            guard goalLink.waitForExistence(timeout: 5) else { return false }
            goalLink.tap()
            guard app.navigationBars["目標"].waitForExistence(timeout: 5) else { return false }
            // 見直した点が3つ（目標を立てたときと、2回の見直し）あるので、1日の目安のカードに推定消費カロリーと目安の階段のグラフが出る
            let ready =
                app.descendants(matching: .any)["goal-weight-chart"].waitForExistence(timeout: 5)
                && app.descendants(matching: .any)["goal-energy-chart"].exists
            // グラフが描き終えるまで少し待つ
            Thread.sleep(forTimeInterval: 1)
            return ready
        case .textMeal:
            guard Self.waitForTodaysWeight(app), app.composerField.waitForExistence(timeout: 5)
            else { return false }
            app.composerField.tap()
            app.composerField.typeText("朝はお茶漬けを食べた")
            app.buttons["composer-send"].tap()
            // 食事と読み分けられると吹き出しの下に食事の行がつながり、推定が届くと料理の名前になる
            let card = app.buttons.matching(
                NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "meal-card", "お茶漬け")
            ).firstMatch
            guard card.waitForExistence(timeout: 30) else { return false }
            return Self.dismissKeyboard(app)
        }
    }

    private static let timeZone = "Asia/Tokyo"

    @MainActor private func open(
        api: String, now: UITestNow = .listingSampleWednesday, photo: String? = nil
    ) -> XCUIApplication {
        .launched(
            account: "signed-in", api: api, healthLatestKilograms: nil,
            pickedPhotos: photo.map { UITestPickedPhotos(count: 1, files: [Self.photoPath($0)]) },
            now: now,
            // 前に開いたときに取り終えた記録をキャッシュに持って開く。空から取りに行くと、今朝の体重が届く前に体重の知らせの時刻（8:00）を過ぎたと判じて、知らせのカードを出すことがある
            cacheHoldsRecords: true, timeZone: Self.timeZone, japaneseLocale: true,
            listingReplyShape: replyShape)
    }

    /// 今朝 7:00 の体重（daily-guide-example.json の 2026-01-21 の weightKg）が出て、読み込み中でない
    @MainActor private static func waitForTodaysWeight(_ app: XCUIApplication) -> Bool {
        app.staticText(containing: "77.8 kg").waitForExistence(timeout: 10)
            && !app.staticTexts["記録を読み込んでいます…"].exists
    }

    /// 体重のステッパー（知らせの中。体重のシートの中でも同じ）の初めの値（前回の 1月20日の 77.7 kg）を 0.1 kg 上げ、今朝の体重（daily-guide-example.json の 2026-01-21 の weightKg、77.8 kg）にする。キーボードは出さない
    @MainActor private static func stepWeight(in container: XCUIElement, app: XCUIApplication)
        -> Bool
    {
        let increase = container.buttons["0.1 kg 増やす"]
        guard increase.waitForExistence(timeout: 10) else { return false }
        increase.tap()
        let shown = container.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "77.8", "77.8")
        ).firstMatch
        guard shown.waitForExistence(timeout: 5) else { return false }
        // ステッパーの値の動き（シートなら上がる動きも）が終わるまで少し待つ
        Thread.sleep(forTimeInterval: 1)
        return !app.keyboards.firstMatch.exists
    }

    /// 「写真」で選び、今日の写真の食事のカードに、この文が出るまで待つ
    @MainActor private static func pickPhoto(_ app: XCUIApplication, until text: String) -> Bool {
        guard waitForTodaysWeight(app) else { return false }
        let photos = app.buttons["composer-photos"]
        guard photos.waitForExistence(timeout: 5) else { return false }
        photos.tap()
        let shown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text),
            object: todaysPhotoMealCard(app))
        guard XCTWaiter().wait(for: [shown], timeout: 30) == .completed else { return false }
        // この端末で選んだ写真は元の写真から読むのですぐ出るが、読み終えたことは読み上げに出ないので、描き終えるまで少し待つ
        Thread.sleep(forTimeInterval: 2)
        return true
    }

    /// 今日 9:41 に選んだ写真の食事のカード。昨日までの書いた食事のカード（7:30・12:30・19:00 に送った）と、送った時刻で見分ける
    @MainActor private static func todaysPhotoMealCard(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND value CONTAINS %@", "meal-card", "9:41")
        ).firstMatch
    }

    /// 送ったあとも書く欄に残るキーボードを、今日の日の見出し（押しても何も起きない文）を押して下げる
    @MainActor private static func dismissKeyboard(_ app: XCUIApplication) -> Bool {
        let heading = app.otherElements["day-section-2026-01-21"].staticTexts.firstMatch
        guard heading.waitForExistence(timeout: 5) else { return false }
        heading.tap()
        guard app.keyboards.firstMatch.waitForNonExistence(timeout: 5) else { return false }
        // キーボードが下がってタイムラインが詰め直すまで少し待つ
        Thread.sleep(forTimeInterval: 1)
        return true
    }

    /// LP の版 a の見本の写真（site/public/landing-a/<name>.webp）
    private static func photoPath(_ name: String) -> String {
        // このファイルは ios/NuToriUITests/ にある
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "site/public/landing-a/\(name).webp")
            .path(percentEncoded: false)
    }
}
