import XCTest

/// 1日の丸の帯の丸を押す → 日のまとめが開く → 日を送る → 「タイムラインでこの日を見る」で、タイムラインがその日へ移り、題がその日になる。
///
/// 選んだ日の区切りへ動かすと決める規則と、題に出す日を決める規則は NuToriCore の単体テスト（TimelineViewportTests の「一番下へ戻す」と「題と1日の丸の帯に出す日」）が見る。
/// ここで見るのは SwiftUI の癖: シートが閉じるのと同じ更新で出した指示でも、ScrollViewProxy の scrollTo が、その更新で並べ足した遠い日（21日前。開いたときには並べていない）に着くこと、
/// 着いたあとの日の区切りの位置（GeometryReader と preference）が届いて、題がその日に変わること
///
/// 日のまとめの「体重」の行を押すと、シートが閉じてタイムラインの上に体重の画面が積まれ、「すべての記録」へも潜れることも見る
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
        // 体重の行は押せる行なので、値は行のラベルで見る
        let weightRow = app.buttons["day-summary-weight"]
        XCTAssertTrue(waitUntil(weightRow, matches: "label CONTAINS %@", "72.4 kg"))
        for _ in 0..<21 {
            app.buttons["前の日"].tap()
        }
        XCTAssertTrue(waitUntil(weightRow, matches: "label CONTAINS %@", "70.0 kg"))
        XCTAssertTrue(weightRow.label.contains("ほか1件"))
        XCTAssertFalse(app.buttons["前の日"].isEnabled)
        app.buttons["次の日"].tap()
        XCTAssertTrue(waitUntil(weightRow, matches: "label CONTAINS %@", "記録なし"))
        app.buttons["前の日"].tap()
        XCTAssertTrue(waitUntil(weightRow, matches: "label CONTAINS %@", "70.0 kg"))
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

    func test_日のまとめの体重の行から体重の画面とすべての記録へ潜れること() {
        app.buttons["ring-\(todayIdentifier)"].tap()
        XCTAssertTrue(app.otherElements["day-summary"].waitForExistence(timeout: 5))

        app.buttons["day-summary-weight"].tap()
        XCTAssertTrue(app.otherElements["day-summary"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["weight-screen"].waitForExistence(timeout: 5))
        // 記録のある日が22日あるので、最近の記録は5日に絞り、その先へ潜る行を置く
        attachScreenshot(of: app, named: "日のまとめの体重の行から開いた体重の画面")
        let historyLink = app.buttons["weight-history-link"]
        XCTAssertTrue(app.scrollUntilExists(historyLink))
        attachScreenshot(of: app, named: "最近の記録の5日とすべての記録への行")

        historyLink.tap()
        let history = app.descendants(matching: .any)["weight-history-screen"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "すべての記録")
        // 最近の記録の5日に入らない、使い始めた日の行まで並ぶ
        let startedDayRow = history.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "70.0 kg")
        ).firstMatch
        XCTAssertTrue(app.scrollUntilExists(startedDayRow, maxSwipes: 8))
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
