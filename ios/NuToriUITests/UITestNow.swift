import XCTest

/// UI テストでアプリの時計を止める時刻。起動の値 `UI_TEST_NOW` で渡し、アプリのタイムゾーン（`TZ`）の時計の時刻として読ませる。
/// 開いた時刻でテストの結果が変わらないよう、どの UI テストもどれかに止める
enum UITestNow: String {
    /// 体重の知らせの時刻（いつもの時刻が届いていなければ 8:00）より前の朝。知らせは出ない
    case morningBeforeNotice = "2026-10-05T06:30"
    /// 体重の知らせの時刻を過ぎた朝。今日の体重記録が無ければ知らせが出る
    case morningAfterNotice = "2026-10-05T09:00"

    /// 止めた時刻を、そのタイムゾーンの時刻として読む。テストの側で、アプリと同じ「今日」を数えるため。
    /// アプリの側の `DeviceClock.frozen(atLaunchValue:in:)` と同じ形で読む
    func date(in timeZone: TimeZone) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return try XCTUnwrap(formatter.date(from: rawValue))
    }
}
