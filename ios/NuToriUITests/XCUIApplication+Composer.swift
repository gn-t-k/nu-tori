import XCTest

extension XCUIApplication {
    /// 入力欄の書く欄。縦に伸びる TextField（UITextView）なので、種類を問わずに探す
    @MainActor var composerField: XCUIElement {
        descendants(matching: .any)["composer-field"]
    }
}
