import XCTest

/// 食事を画面に収まらないだけ並べ、一番下から少しだけ（入力欄の高さより少なく）上へ送って指を離す → 下端に着き、最後の食事のカードが入力欄の「写真」より上に見える（#469）。
/// 写真の選択は起動の値で差し替える（選ぶ画面を開かずに1枚選んだことにする）
@MainActor
final class SettleAtTimelineEndAfterReleasingNearEndUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: nil,
            pickedPhotoCount: 1, now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        let photos = app.buttons["composer-photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 5))
        for index in 0..<Self.mealsFillingScreen {
            photos.tap()
            XCTAssertTrue(mealCards.element(boundBy: index).waitForExistence(timeout: 10))
        }
        let shown = try await waitUntil(newestMealCard, isAbove: photos)
        attachScreenshot(of: app, named: "一番下に食事を並べたタイムライン")
        XCTAssertTrue(shown, "指を離す前から、最後の食事のカードが入力欄の下に隠れている")
    }

    func test_一番下の近くまで戻して指を離すと最後の食事のカードが入力欄の上に見えること() async throws {
        let timeline = app.otherElements["timeline"]
        let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        // 勢いを付けずに動かして止めてから離し、離した位置に止まるようにする
        start.press(
            forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: Self.dragDistance)),
            withVelocity: .slow, thenHoldForDuration: 0.5)
        attachScreenshot(of: app, named: "一番下の近くで指を離したタイムライン")

        let shown = try await waitUntil(newestMealCard, isAbove: app.buttons["composer-photos"])
        attachScreenshot(of: app, named: "指を離して止まったタイムライン")
        XCTAssertTrue(shown, "最後の食事のカードが入力欄の下に隠れている")
    }

    /// カードが画面の高さを超えて並び、遡れるようになる数
    private static let mealsFillingScreen = 5
    /// 上へ送る量。入力欄の高さ（iPhone 18 Pro で 220）より少なく、下の余白とカードの間（合わせて 30 ほど）より多い
    private static let dragDistance: CGFloat = 120

    private var mealCards: XCUIElementQuery {
        app.buttons.matching(identifier: "meal-card")
    }

    private var newestMealCard: XCUIElement {
        mealCards.element(boundBy: Self.mealsFillingScreen - 1)
    }
}
