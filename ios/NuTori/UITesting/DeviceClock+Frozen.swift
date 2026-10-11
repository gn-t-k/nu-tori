#if DEBUG
    import Foundation
    import Synchronization
    import UIKit

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

        /// ホームへ出てから開き直すたびに、1日進む時計。閉じているあいだに日付が変わったことにする
        func advancingDayOnReturn() -> DeviceClock {
            let returns = Mutex(Returns())
            let center = NotificationCenter.default
            // 起動のときにも前に出る知らせが来るので、裏に回ったあとの分だけ数える
            _ = center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
            ) { _ in
                returns.withLock { $0.isInBackground = true }
            }
            _ = center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
            ) { _ in
                returns.withLock { state in
                    if state.isInBackground {
                        state.isInBackground = false
                        state.count += 1
                    }
                }
            }
            let now = self.now
            return DeviceClock(
                now: { now().addingTimeInterval(86400 * Double(returns.withLock { $0.count })) },
                timeZone: timeZone)
        }

        private struct Returns {
            var isInBackground = false
            var count = 0
        }
    }
#endif
