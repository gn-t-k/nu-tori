import XCTest

extension XCUIApplication {
    /// 食事の画面は List なので、画面の外の行はまだ作られていない。下へ送って作らせる
    @MainActor func scrollUntilExists(_ element: XCUIElement) -> Bool {
        for _ in 0..<5 where !element.exists {
            swipeUp()
        }
        return element.exists
    }

    /// 確かめ（confirmationDialog）の「食事を削除」。食事の画面の行の「食事を削除」と見分ける
    @MainActor var mealDeletionConfirm: XCUIElement {
        buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "食事を削除", "meal-delete")
        ).firstMatch
    }
}
