import XCTest

extension XCUIApplication {
    /// 戻るのボタン（「‹ 食事」）は版によって文字を出さないので、並びの最初のボタンで押す
    @MainActor func tapBack(from title: String) {
        navigationBars[title].buttons.element(boundBy: 0).tap()
    }
}
