import XCTest

extension XCUIApplication {
    /// List や ScrollView の中では、画面の外の要素はまだ作られていない。下へ送って作らせる
    @MainActor func scrollUntilExists(_ element: XCUIElement) -> Bool {
        for _ in 0..<5 where !element.exists {
            swipeUp()
        }
        return element.exists
    }
}
