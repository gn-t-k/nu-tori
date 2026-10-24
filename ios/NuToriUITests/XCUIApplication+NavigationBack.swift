import XCTest

extension XCUIApplication {
    /// ナビゲーションバーの「戻る」を押す。戻るのボタン（「‹ 食事」）は版によって文字を出さないので、並びの最初のボタンで押す。
    /// 画面の名前を渡すと、その画面のナビゲーションバーの中で探す
    @MainActor func tapBack(from title: String? = nil) {
        let buttons = title.map { navigationBars[$0].buttons } ?? navigationBars.buttons
        buttons.element(boundBy: 0).tap()
    }
}
