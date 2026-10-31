import XCTest

/// 見本の場面と、撮る生の画面の対応。掲載情報と LP の手順の絵の生の画面は、ここに並べた場面だけを撮る（`ListingScreenshots`）。
///
/// 名前（rawValue）は合成のコマンドとの約束で、生の画面のファイル名（`step-weigh.png`）になる。
/// 場面を足すときは case を足し、`launch()` と `prepare(_:)` に書く。見本の記録は作り物だけにし、値は LP の見本とそろえる（`ios/AGENTS.md` の「見本の場面」）
enum ListingScene: String, CaseIterable {
    /// 朝、体重を記録したタイムライン（LP の手順1）
    case stepWeigh = "step-weigh"
    /// 食べる前に撮った写真が、推定を待ちながらタイムラインに並んだところ（LP の手順2）
    case stepPhoto = "step-photo"
    /// 毎週の見直しで1日の目安が変わった知らせ（LP の手順3）
    case stepGuide = "step-guide"

    /// 場面の記録と時計で開く。記録は、アプリの UI テストの差し替えの見本の人（`UITestLaunch.listingSampleScenario()`）。
    /// アプリの時計は、撮る画面の状態の表示（9:41）とそろえ、タイムゾーンは日本に固める
    @MainActor func launch() -> XCUIApplication {
        switch self {
        case .stepWeigh, .stepGuide:
            .launched(
                account: "signed-in", api: "listing-sample", healthLatestKilograms: nil,
                now: self == .stepGuide ? .listingSampleMonday : .listingSampleWednesday,
                timeZone: Self.timeZone, japaneseLocale: true)
        case .stepPhoto:
            // 写真は LP の見本と同じ Wikimedia Commons の CC0（Ocdp）のおにぎりで、nu-tori の利用者の食事ではない。
            // 出どころは site/src/pages/landing-a/example-photo-meals.ts。リポジトリに2つ置かないよう、LP の写真をそのまま読む
            .launched(
                account: "signed-in", api: "listing-sample", healthLatestKilograms: nil,
                pickedPhotos: UITestPickedPhotos(count: 1, files: [Self.onigiriPhotoPath]),
                now: .listingSampleWednesday, timeZone: Self.timeZone, japaneseLocale: true)
        }
    }

    /// 撮る前の操作をし、出るべきものが出るまで待つ。出なければ false（空の画面や読み込み中を撮らない）
    @MainActor func prepare(_ app: XCUIApplication) -> Bool {
        switch self {
        case .stepWeigh:
            // 今朝 7:00 の体重（daily-guide-example.json の 2026-01-21 の weightKg）
            return app.staticText(containing: "77.8 kg").waitForExistence(timeout: 10)
                && !app.staticTexts["記録を読み込んでいます…"].exists
        case .stepPhoto:
            guard app.staticText(containing: "77.8 kg").waitForExistence(timeout: 10) else {
                return false
            }
            let photos = app.buttons["composer-photos"]
            guard photos.waitForExistence(timeout: 5) else { return false }
            photos.tap()
            // 送り終えて推定中が届くと、カードの状態の1行が出る。見本の場面は推定を終えない
            let card = app.buttons["meal-card"]
            let estimating = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", "推定しています…"), object: card)
            guard XCTWaiter().wait(for: [estimating], timeout: 30) == .completed else {
                return false
            }
            // この端末で選んだ写真は元の写真から読むのですぐ出るが、読み終えたことは読み上げに出ないので、描き終えるまで少し待つ
            Thread.sleep(forTimeInterval: 2)
            return true
        case .stepGuide:
            // 今日の 0:05 の見直しで、1日の目安が 1,900 kcal から 1,750 kcal に変わった（daily-guide-example.json の reviews の2つめ）
            return app.descendants(matching: .any)["daily-guide-change-notice"]
                .waitForExistence(timeout: 10)
                && app.buttons["weekly-review-card"].exists
        }
    }

    private static let timeZone = "Asia/Tokyo"

    private static var onigiriPhotoPath: String {
        // このファイルは ios/NuToriUITests/ にある
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "site/public/landing-a/onigiri.webp")
            .path(percentEncoded: false)
    }
}
