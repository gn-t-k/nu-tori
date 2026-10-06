import XCTest

extension XCTestCase {
    /// 要素が条件に合うまで待つ。推定の結果は、取りに行く間隔（数秒おき）で届く
    @MainActor func waitUntil(_ element: XCUIElement, matches format: String, _ argument: String)
        -> Bool
    {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format, argument), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 30) == .completed
    }
}
