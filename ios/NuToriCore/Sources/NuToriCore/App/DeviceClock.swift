public import Foundation

/// 端末の今とタイムゾーン。アプリのターゲットは、今とタイムゾーンをここから読む（UI テストは止めた時計に差し替える）
public struct DeviceClock: Sendable {
    public let now: @Sendable () -> Date
    public let timeZone: @Sendable () -> TimeZone

    public static let live = DeviceClock(now: { .now }, timeZone: { .current })

    public init(now: @escaping @Sendable () -> Date, timeZone: @escaping @Sendable () -> TimeZone) {
        self.now = now
        self.timeZone = timeZone
    }

    public func today() -> CalendarDay {
        CalendarDay(containing: now(), in: timeZone())
    }
}
