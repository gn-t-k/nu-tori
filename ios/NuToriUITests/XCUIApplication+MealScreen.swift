import XCTest

extension XCUIApplication {
    /// 確かめ（confirmationDialog）の「食事を削除」。食事の画面の行の「食事を削除」と見分ける
    @MainActor var mealDeletionConfirm: XCUIElement {
        buttons.matching(
            NSPredicate(format: "label == %@ AND identifier != %@", "食事を削除", "meal-delete")
        ).firstMatch
    }

    /// 食事の画面の料理の行。行の文字は料理の名前と量なので、名前を含むかで探す
    @MainActor func mealDish(named name: String) -> XCUIElement {
        buttons.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "meal-dish", name)
        ).firstMatch
    }
}
