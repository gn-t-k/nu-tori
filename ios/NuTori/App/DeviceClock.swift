import Foundation
import NuToriCore

/// 端末の今とタイムゾーン。アプリのターゲットは、今とタイムゾーンをここから読む（UI テストは止めた時計に差し替える）
nonisolated struct DeviceClock: Sendable {
    let now: @Sendable () -> Date
    let timeZone: @Sendable () -> TimeZone

    static let live = DeviceClock(now: { .now }, timeZone: { .current })

    func today() -> CalendarDay {
        CalendarDay(containing: now(), in: timeZone())
    }
}
