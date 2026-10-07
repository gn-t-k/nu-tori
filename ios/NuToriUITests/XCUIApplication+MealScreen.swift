import XCTest

extension XCUIApplication {
    /// 確かめ（confirmationDialog）の「食事を削除」。食事の画面の行の「食事を削除」と見分ける
    @MainActor var mealDeletionConfirm: XCUIElement {
        buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "食事を削除", "meal-delete")
        ).firstMatch
    }
}
