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

    public var sourceAndTimeLabel: String {
        let clock = WeightAmountText.clock(clockTime)
        switch inputSource {
        case .manual:
            return "手で記録・\(clock)"
        case .imported(let source):
            return "\(source.appName) から・\(clock)"
        }
    }

    public func correction(replacingKilograms kilograms: Double) -> WeightRecord? {
        let nextTenths = Self.tenths(of: kilograms)
        let rounded = Double(nextTenths) / 10
        guard AcceptedRange.weightKilograms.bounds.contains(rounded) else {
            return nil
        }
        guard nextTenths != Self.tenths(of: self.kilograms) else {
            return nil
        }
        return WeightRecord(
            id: id,
            kilograms: rounded,
            instant: instant,
            timeZone: timeZone,
            inputSource: inputSource,
            version: version + 1
        )
    }

    public enum InputSource: Hashable, Sendable {
        case manual
        case imported(ImportedSource)
    }

    public struct ImportedSource: Hashable, Sendable {
        public let appName: String
        public let bundleId: String
        public let healthKitSampleId: UUID
        public let bodyFat: BodyFat?

        public init(
            appName: String,
            bundleId: String,
            healthKitSampleId: UUID,
            bodyFat: BodyFat?
        ) {
            self.appName = appName
            self.bundleId = bundleId
            self.healthKitSampleId = healthKitSampleId
            self.bodyFat = bodyFat
        }

        public struct BodyFat: Hashable, Sendable {
            /// % の値（25.0）
            public let percentage: Double
            public let healthKitSampleId: UUID

            public init(percentage: Double, healthKitSampleId: UUID) {
                self.percentage = percentage
                self.healthKitSampleId = healthKitSampleId
            }
        }
    }

    private static func tenths(of kilograms: Double) -> Int {
        Int((kilograms * 10).rounded())
    }

    func remeasured(_ kilograms: Double, at instant: Date, in timeZone: TimeZone) -> WeightRecord {
        WeightRecord(
            id: id,
            kilograms: kilograms,
            instant: instant,
            timeZone: timeZone,
            inputSource: inputSource,
            version: version + 1
        )
    }
}
