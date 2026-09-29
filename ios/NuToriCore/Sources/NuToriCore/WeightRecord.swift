public import Foundation

public struct WeightRecord: Hashable, Sendable {
    public let id: UUID
    public let kilograms: Double
    public let instant: Date
    public let timeZone: TimeZone
    public let inputSource: InputSource
    public let version: Int

    public init(
        id: UUID,
        kilograms: Double,
        instant: Date,
        timeZone: TimeZone,
        inputSource: InputSource,
        version: Int
    ) {
        self.id = id
        self.kilograms = kilograms
        self.instant = instant
        self.timeZone = timeZone
        self.inputSource = inputSource
        self.version = version
    }

    public var day: CalendarDay {
        CalendarDay(containing: instant, in: timeZone)
    }

    public var clockTime: ClockTime {
        ClockTime(containing: instant, in: timeZone)
    }

    public enum InputSource: Hashable, Sendable {
        case manual
        case imported
    }
}
