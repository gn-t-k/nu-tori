import XCTest

/// 食事を画面に収まらないだけ並べてタイムラインを遡った状態で、いちばん下に項目を足す（写真を選ぶ、文章を送る） → 一番下に戻る。
/// 写真の選択は起動の値で差し替える（選ぶ画面を開かずに1枚選んだことにする）
///
/// 遡っていても一番下へ動かし、足されるカードを追うと決める規則は NuToriCore の単体テスト（TimelineViewportTests の「一番下へ戻す」）が見る。
/// ここで見るのは SwiftUI の癖: 遡って画面の外へ出た下端へ、ScrollViewProxy の scrollTo が着けること、
/// 指示を次の更新で実行しても（動かす口は ScrollViewReader の中にしか無い）、あとから足されるカードが入力欄の上に見えること
@MainActor
final class ReturnToTimelineEndWhenScrolledBackUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: nil,
            pickedPhotos: UITestPickedPhotos(count: 1), now: .morningBeforeNotice,
            timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
        for index in 0..<Self.mealsFillingScreen {
            app.buttons["composer-photos"].tap()
            XCTAssertTrue(mealCards.element(boundBy: index).waitForExistence(timeout: 10))
        }
        let newest = mealCards.element(boundBy: Self.mealsFillingScreen - 1)
        XCTAssertTrue(waitUntilHittable(newest))
        app.otherElements["timeline"].swipeDown()
        app.otherElements["timeline"].swipeDown()
        XCTAssertFalse(newest.isHittable)
        attachScreenshot(of: app, named: "遡ったタイムライン")
    }

    func test_遡ってから写真を選ぶと足した食事のカードが見える位置に戻ること() async throws {
        let photos = app.buttons["composer-photos"]
        photos.tap()

        let added = mealCards.element(boundBy: Self.mealsFillingScreen)
        XCTAssertTrue(added.waitForExistence(timeout: 10))
        let shown = try await waitUntil(added, isAbove: photos)
        attachScreenshot(of: app, named: "写真を足して一番下に戻ったタイムライン")
        XCTAssertTrue(shown, "足した食事のカードが入力欄の下に隠れている")
    }

    func test_遡ってから文章を送るとタイムラインの一番下に戻ること() {
        app.composerField.tap()
        app.composerField.typeText("散歩した")
        app.buttons["composer-send"].tap()

        let bubble = app.element("sent-text-bubble", containing: "散歩した")
        let returned = waitUntilHittable(bubble)
        attachScreenshot(of: app, named: "文章を送って一番下に戻ったタイムライン")
        XCTAssertTrue(returned, "送った文章の吹き出しが見える位置に戻っていない")
    }

    /// カードが画面の高さを超えて並び、遡れるようになる数
    private static let mealsFillingScreen = 5

    private var mealCards: XCUIElementQuery {
        app.buttons.matching(identifier: "meal-card")
    }
}
