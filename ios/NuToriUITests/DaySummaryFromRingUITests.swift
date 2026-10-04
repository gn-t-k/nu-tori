import XCTest

@MainActor
final class DaySummaryFromRingUITests: XCTestCase {
    private var app = XCUIApplication()
    private var started = StartedDay(identifier: "", label: "")
    private var todayIdentifier = ""

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        let days = try Self.days()
        started = days.started
        todayIdentifier = days.todayIdentifier
        app = .launched(
            account: "signed-in", api: "day-ring", healthLatestKilograms: nil,
            now: Self.now, timeZone: Self.timeZoneIdentifier)
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
    }

    func test_丸を押すと日のまとめが開いてタイムラインのその日へ移ること() {
        app.buttons["ring-\(todayIdentifier)"].tap()

        XCTAssertTrue(app.otherElements["day-summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticText(containing: "72.4 kg").exists)
        for _ in 0..<21 {
            app.buttons["前の日"].tap()
        }
        XCTAssertTrue(app.staticText(containing: "70.0 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticText(containing: "ほか1件").exists)
        XCTAssertFalse(app.buttons["前の日"].isEnabled)
        app.buttons["次の日"].tap()
        XCTAssertTrue(app.staticText(containing: "記録なし").waitForExistence(timeout: 5))
        app.buttons["前の日"].tap()
        XCTAssertTrue(app.staticText(containing: "70.0 kg").waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "使い始めた日のまとめ")

        app.buttons["タイムラインでこの日を見る"].tap()
        XCTAssertTrue(app.otherElements["day-summary"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["day-section-\(started.identifier)"].waitForExistence(
                timeout: 5))
        XCTAssertTrue(app.staticTexts[started.label].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.staticTexts[started.label].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticText(containing: "70.0 kg").isHittable)
        XCTAssertFalse(app.staticText(containing: "72.4 kg").isHittable)
        attachScreenshot(of: app, named: "タイムラインで使い始めた日を見た")
    }

    private struct StartedDay {
        let identifier: String
        let label: String
    }

    private static let now = UITestNow.morningBeforeNotice
    private static let timeZoneIdentifier = "Asia/Tokyo"

    private static func days() throws -> (started: StartedDay, todayIdentifier: String) {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = try XCTUnwrap(TimeZone(identifier: timeZoneIdentifier))
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: try now.date(in: timeZone))
        let started = try XCTUnwrap(calendar.date(byAdding: .day, value: -21, to: today))
        return (
            started: try startedDay(started, calendar: calendar),
            todayIdentifier: try identifier(for: today, calendar: calendar)
        )
    }

    private static func startedDay(_ date: Date, calendar: Calendar) throws -> StartedDay {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        let month = try XCTUnwrap(parts.month)
        let day = try XCTUnwrap(parts.day)
        let weekday = try XCTUnwrap(parts.weekday)
        return StartedDay(
            identifier: try identifier(for: date, calendar: calendar),
            label: "\(month)月\(day)日（\(symbols[weekday - 1])）"
        )
    }

    private static func identifier(for date: Date, calendar: Calendar) throws -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = try XCTUnwrap(parts.year)
        let month = try XCTUnwrap(parts.month)
        let day = try XCTUnwrap(parts.day)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
