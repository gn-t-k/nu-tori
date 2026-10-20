import XCTest

extension XCUIApplication {
    /// List や ScrollView の中では、画面の外の要素はまだ作られていない。下へ送って作らせる。
    /// いちばん大きな文字では1画面に入る量が少ないので、送る回数を増やして渡す
    @MainActor func scrollUntilExists(_ element: XCUIElement, maxSwipes: Int = 5) -> Bool {
        for _ in 0..<maxSwipes where !element.exists {
            swipeUp()
        }
        return element.exists
    }
}
