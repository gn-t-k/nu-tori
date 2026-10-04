#if DEBUG
    import Foundation

    extension DeviceClock {
        /// 進まない時計。UI テストの結果が、開いた時刻（体重の知らせの時刻を過ぎたか、日付）で変わらないようにする。
        /// `UI_TEST_NOW` の値（`2026-10-05T06:30` の形）を、そのタイムゾーンの時計の時刻として読む。読めなければ nil。
        /// UI テストの側の `UITestNow.date(in:)` と同じ形で読む
        static func frozen(atLaunchValue value: String, in timeZone: TimeZone) -> DeviceClock? {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            guard let instant = formatter.date(from: value) else { return nil }
            return DeviceClock(now: { instant }, timeZone: { timeZone })
        }
    }
#endif
