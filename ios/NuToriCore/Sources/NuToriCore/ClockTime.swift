public import Foundation

public struct ClockTime: Hashable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init(containing instant: Date, in timeZone: TimeZone) {
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: timeZone, from: instant)
        self.init(hour: components.hour!, minute: components.minute!)
    }

    /// 時刻に時差を足した UTC の時計の時刻。時差しか分からない食事の時刻に使う
    public init(containing instant: Date, utcOffsetSeconds: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents(
            [.hour, .minute], from: instant.addingTimeInterval(TimeInterval(utcOffsetSeconds)))
        self.init(hour: components.hour!, minute: components.minute!)
    }
}
