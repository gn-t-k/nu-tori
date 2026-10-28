import XCTest

extension XCTestCase {
    /// 要素が条件に合うまで待つ。推定の結果は、取りに行く間隔（数秒おき）で届く
    @MainActor func waitUntil(
        _ element: XCUIElement, matches format: String, _ argument: String,
        timeout: TimeInterval = 30
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format, argument), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// 要素が画面の中に入って押せるようになるまで待つ
    @MainActor func waitUntilHittable(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    /// 要素の下端が、もう1つの要素の上端より上に来るまで待つ
    @MainActor func waitUntil(_ element: XCUIElement, isAbove other: XCUIElement) async throws
        -> Bool
    {
        let deadline = ContinuousClock.now + .seconds(10)
        while element.frame.maxY > other.frame.minY {
            if ContinuousClock.now >= deadline {
                return false
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        return true
    }
}
