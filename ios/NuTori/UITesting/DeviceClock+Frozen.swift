#if DEBUG
    import Foundation
    import NuToriCore
    import Synchronization
    import UIKit

    extension DeviceClock {
        /// ほとんど進まない時計。UI テストの結果が、開いた時刻（体重の知らせの時刻を過ぎたか、日付）で変わらないようにする。
        /// `UI_TEST_NOW` の値（`2026-10-05T06:30` の形）を、そのタイムゾーンの時計の時刻として読む。読めなければ nil。
        /// UI テストの側の `UITestNow.date(in:)` と同じ形で読む。
        /// 起動してからの経過（`elapsed`）の 1/1000 だけ進める。止めると、続けて送った文章が同じ時刻になり、ID の順で並んで送った順にならないため（#586）。サーバーは時刻をミリ秒で持つので、1秒あけた操作は 1ms ずれて順が残る。
        /// 10 分回しても 0.6 秒しか進まず、分の表示は変わらない
        nonisolated static func frozen(
            atLaunchValue value: String, in timeZone: TimeZone,
            elapsed: @escaping @Sendable () -> TimeInterval
        ) -> DeviceClock? {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            guard let instant = formatter.date(from: value) else { return nil }
            return DeviceClock(
                now: { instant.addingTimeInterval(elapsed() / 1000) }, timeZone: { timeZone })
        }

        /// 作ってからの経過。端末の時計を直しても戻らない、起動してからの時間で測る
        nonisolated static func elapsedSinceCreated() -> @Sendable () -> TimeInterval {
            let start = ProcessInfo.processInfo.systemUptime
            return { ProcessInfo.processInfo.systemUptime - start }
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
