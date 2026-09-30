import XCTest

extension XCTestCase {
    /// 失敗したときに画面を見られるよう、確かめた画面を残す
    @MainActor func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
