import XCTest

/// 掲載情報と LP の手順の絵に使う生の画面を、見本の場面（`ListingScene`）ごとに撮る。撮るたびにアプリの時計の時刻が変わらないことも確かめる。
///
/// ふつうの UI テストの回（`scripts/check ios-ui-test`）には入れず、`scripts/check ios-screenshots` だけが回す。
/// 撮った画面は場面の名前の添付にし、`scripts/check ios-screenshots` が xcresult から名前で取り出す。
/// 状態の表示（9:41、電波と Wi-Fi と電池が満ちた形）と、明るい表示と、文字の大きさは、`scripts/check` がシミュレーターに固める
@MainActor
final class ListingScreenshots: XCTestCase {
    func test_見本の場面の生の画面を撮ること() {
        // 1つの場面が出なくても、残りの場面は撮る
        continueAfterFailure = true
        for scene in ListingScene.allCases {
            XCTContext.runActivity(named: scene.rawValue) { _ in
                let app = scene.launch()
                defer { app.terminate() }
                guard scene.prepare(app) else {
                    XCTFail("\(scene.rawValue) の出るべきものが出ないので、撮らない")
                    return
                }
                // 状態の表示も入れるため、アプリの窓でなく画面全体を撮る
                let attachment = XCTAttachment(
                    uniformTypeIdentifier: "public.png", name: scene.rawValue,
                    payload: XCUIScreen.main.screenshot().pngRepresentation)
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    /// 撮るたびに日付や時刻が変わると、生の画面と状態の表示（9:41）がずれる。同じ場面を2回開き、アプリの時計から出る時刻が2回とも見本の時刻のままかを見る。
    /// 場面は、今日選んだ写真の送った時刻（アプリの時計で決まる）が出る `stepPhoto`。撮った画面は添付しない（生の画面は上のテストだけが残す）。
    /// 状態の表示の時刻はここでは見ない。SpringBoard の読み上げの値は `simctl status_bar` の上書きを映さず、画面に 9:41 と出ていても本物の時刻を返す
    func test_同じ場面を2回開いても_アプリの時計の時刻が見本の時刻のままであること() throws {
        // `ListingScene.stepPhoto` は水曜の時刻（`UITestNow.listingSampleWednesday`）で開く
        let expected = ClockReading(day: "2026-01-21", sentTime: "9:41")
        var readings: [ClockReading] = []
        for round in 1...2 {
            let app = ListingScene.stepPhoto.launch()
            defer { app.terminate() }
            XCTAssertTrue(ListingScene.stepPhoto.prepare(app), "\(round) 回目の場面が出ない")
            readings.append(try Self.clockReading(in: app))
        }
        XCTAssertEqual(readings, [expected, expected])
    }

    /// アプリの時計から出る時刻: 一番新しい日の見出しの日付と、その日の写真の食事のカードの送った時刻
    private struct ClockReading: Equatable {
        let day: String
        let sentTime: String
    }

    private static func clockReading(in app: XCUIApplication) throws -> ClockReading {
        // タイムラインは一番下に着いているので、一番新しい日の区切りは画面にある。識別子は day-section-<yyyy-MM-dd>
        let prefix = "day-section-"
        let days = app.otherElements
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .allElementsBoundByIndex
            .map { String($0.identifier.dropFirst(prefix.count)) }
        let day = try XCTUnwrap(days.max(), "日の区切りが無い")
        // 今日の記録は、見本の人の朝の体重と、この場面で選んだ写真の食事だけ。カードの値は「<送った時刻>に送った」
        let card = app.otherElements[prefix + day].buttons["meal-card"].firstMatch
        XCTAssertTrue(card.exists, "\(day) に食事のカードが無い")
        let value = try XCTUnwrap(card.value as? String)
        let sentTime = try XCTUnwrap(
            value.firstMatch(of: /\d{1,2}:\d{2}/).map { String($0.output) }, "送った時刻が無い: \(value)")
        return ClockReading(day: day, sentTime: sentTime)
    }
}
