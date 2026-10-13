import XCTest

/// タイムラインの一番下を見たまま、「写真」で食事を続けて足す → 足すたびに、足した食事のカードが入力欄の「写真」より上に見える（#467）。
/// 写真の選択は起動の値で差し替える（選ぶ画面を開かずに1枚選んだことにする）
///
/// 毎回、中身の下端へ動かして追うと決める規則は NuToriCore の単体テスト（TimelineViewportTests の「過去の不具合の場面」の #467）が見る。
/// ここで見るのは SwiftUI の癖: ScrollViewProxy の scrollTo が、中身の全体を名指しすると下の余白まで含めた下端に着くこと、
/// 下端ちょうどにいるときだけ、大きさが変わったときの位置の保ち方（defaultScrollAnchor の .sizeChanges の .bottom）が、足されたカードの分だけ下端を追うこと
@MainActor
final class FollowTimelineEndAfterPickedPhotosInRowUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: nil,
            pickedPhotoCount: 1, now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
    }

    func test_一番下を見たまま写真を続けて選ぶと足した食事のカードが入力欄の上に見えること() async throws {
        for index in 0..<Self.mealsOverflowingScreen {
            let photos = app.buttons["composer-photos"]
            photos.tap()

            let added = mealCards.element(boundBy: index)
            XCTAssertTrue(added.waitForExistence(timeout: 10))
            let shown = try await waitUntil(added, isAbove: photos)
            attachScreenshot(of: app, named: "\(index + 1)枚目を足したタイムライン")
            XCTAssertTrue(shown, "\(index + 1)枚目のカードが入力欄の下に隠れている")
        }
    }

    /// カードが画面の高さを超えて並ぶ数
    private static let mealsOverflowingScreen = 5

    private var mealCards: XCUIElementQuery {
        app.buttons.matching(identifier: "meal-card")
    }
}
