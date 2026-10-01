public import Foundation

public struct WeightEntry: Sendable {
    public let initialValue: InitialValue

    public init(weightRecords: [WeightRecord], today: CalendarDay) {
        let latestFirst = weightRecords.sorted { $0.instant > $1.instant }
        let recordToCorrect = latestFirst.first { $0.inputSource == .manual && $0.day == today }
        let previousRecord = latestFirst.first { $0.id != recordToCorrect?.id }
        initialValue =
            (recordToCorrect ?? latestFirst.first).map {
                .previous(kilograms: Double(Self.tenths(of: $0.kilograms)) / 10, day: $0.day)
            } ?? .empty
        self.recordToCorrect = recordToCorrect
        self.previousRecord = previousRecord
    }

    public func canRecord(_ kilograms: Double) -> Bool {
        AcceptedRange.weightKilograms.bounds.contains(kilograms)
    }

    public func possibleTypo(for kilograms: Double) -> PossibleTypo? {
        guard let previousRecord else {
            return nil
        }
        // Double のまま比べると、ちょうど 5% のときに誤差で外れることがある
        let tenths = Self.tenths(of: kilograms)
        let previousTenths = Self.tenths(of: previousRecord.kilograms)
        let differenceTenths = abs(tenths - previousTenths)
        guard differenceTenths * 20 >= previousTenths else {
            return nil
        }
        return PossibleTypo(
            direction: tenths > previousTenths ? .heavier : .lighter,
            differenceKilograms: Double(differenceTenths) / 10,
            previousDay: previousRecord.day
        )
    }

    public func write(recording kilograms: Double, at instant: Date, in timeZone: TimeZone) -> Write
    {
        guard let recordToCorrect else {
            return .create(kilograms: kilograms, instant: instant, timeZone: timeZone)
        }
        return .correct(recordToCorrect.remeasured(kilograms, at: instant, in: timeZone))
    }

    public enum InitialValue: Hashable, Sendable {
        case empty
        /// 0.1 kg に丸めた前回の値と、その日
        case previous(kilograms: Double, day: CalendarDay)
    }

    public struct PossibleTypo: Hashable, Sendable {
        public let direction: Direction
        public let differenceKilograms: Double
        public let previousDay: CalendarDay

        public enum Direction: Hashable, Sendable {
            case heavier
            case lighter
        }
    }

    public enum Write: Hashable, Sendable {
        case create(kilograms: Double, instant: Date, timeZone: TimeZone)
        case correct(WeightRecord)
    }

    /// 記録すると直す、今日の手の記録
    private let recordToCorrect: WeightRecord?
    private let previousRecord: WeightRecord?

    private static func tenths(of kilograms: Double) -> Int {
        Int((kilograms * 10).rounded())
    }
}
