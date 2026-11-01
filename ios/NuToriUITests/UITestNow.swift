import XCTest

/// UI テストでアプリの時計を止める時刻。起動の値 `UI_TEST_NOW` で渡し、アプリのタイムゾーン（`TZ`）の時計の時刻として読ませる。
/// 開いた時刻でテストの結果が変わらないよう、どの UI テストもどれかに止める
enum UITestNow: String {
    /// 体重の知らせの時刻（いつもの時刻が届いていなければ 8:00）より前の朝。知らせは出ない
    case morningBeforeNotice = "2026-10-05T06:30"
    /// 体重の知らせの時刻を過ぎた朝。今日の体重記録が無ければ知らせが出る
    case morningAfterNotice = "2026-10-05T09:00"
    /// 見本の人（`ListingScene`）の水曜の朝。撮る画面の状態の表示（9:41）とそろえる
    case listingSampleWednesday = "2026-01-21T09:41"
    /// 見本の人の、2回めの見直しをした月曜の、体重を量る 7:00 より前の朝。今朝の体重が無く、体重の知らせの時刻（8:00）より前なので、0:05 の見直しの知らせがタイムラインの一番下に来る。状態の表示の 9:41 とはそろわない（`ListingScene.stepGuide`）
    case listingSampleMondayBeforeWeighing = "2026-01-19T06:30"

    /// 止めた時刻を、そのタイムゾーンの時刻として読む。テストの側で、アプリと同じ「今日」を数えるため。
    /// アプリの側の `DeviceClock.frozen(atLaunchValue:in:elapsed:)` と同じ形で読む
    func date(in timeZone: TimeZone) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return try XCTUnwrap(formatter.date(from: rawValue))
    }
}
