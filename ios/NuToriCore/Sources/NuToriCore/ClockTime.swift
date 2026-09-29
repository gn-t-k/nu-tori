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
}
