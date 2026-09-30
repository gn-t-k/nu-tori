import Foundation

public struct Timeline: Sendable {
    /// タイムラインに並べる日で、日のまとめで送れる日でもある
    public let dayRange: ClosedRange<CalendarDay>

    public init(input: Input, firstDay: CalendarDay, today: CalendarDay) {
        let weightRecordsByDay = Dictionary(
            grouping: input.weightRecords.filter { $0.day >= firstDay }, by: \.day)
        let lastDay = ([today] + weightRecordsByDay.keys).max()!
        let range = firstDay...max(firstDay, lastDay)
        dayRange = range
        days = range.map { day in
            let records = (weightRecordsByDay[day] ?? []).sorted { $0.instant < $1.instant }
            let lines = input.rejectedLines.filter { $0.record.day == day }
                .sorted { $0.record.instant < $1.record.instant }
            return Day(day: day, items: Self.items(records: records, rejectedLines: lines))
        }
    }

    /// 古い日から新しい日へ
    public let days: [Day]

    /// タイムラインに並べる元になるもの。種類が増えたら欄を足す
    public struct Input: Sendable {
        public let weightRecords: [WeightRecord]
        /// サーバーが受け付けなかった体重記録の行
        public let rejectedLines: [RejectedWeightLine]

        public init(weightRecords: [WeightRecord], rejectedLines: [RejectedWeightLine]) {
            self.weightRecords = weightRecords
            self.rejectedLines = rejectedLines
        }
    }

    public struct Day: Hashable, Sendable {
        public let day: CalendarDay
        /// 時刻の順。受け付けなかった行は、その位置に入る
        public let items: [Item]

        public init(day: CalendarDay, items: [Item]) {
            self.day = day
            self.items = items
        }

        public var representativeWeight: RepresentativeWeight? {
            RepresentativeWeight(
                sameDayRecords: items.compactMap {
                    if case .weightRecord(let record) = $0 { record } else { nil }
                })
        }

        /// 1日の丸の帯に出す、この日の丸
        public var ring: DayRing {
            DayRing(
                hasWeightRecord: items.contains {
                    if case .weightRecord = $0 { true } else { false }
                })
        }
    }

    public enum Item: Hashable, Sendable, Identifiable {
        case weightRecord(WeightRecord)
        case rejectedWeightLine(RejectedWeightLine)

        public var id: String {
            switch self {
            case .weightRecord(let record): "record-\(record.id.uuidString)"
            case .rejectedWeightLine(let line): "rejection-\(line.record.id.uuidString)"
            }
        }
    }

    private static func items(
        records: [WeightRecord], rejectedLines: [RejectedWeightLine]
    ) -> [Item] {
        var items = records.map { Item.weightRecord($0) }
        for line in rejectedLines {
            switch line.placement {
            case .belowRecord:
                if let index = items.firstIndex(where: { item in
                    guard case .weightRecord(let record) = item else { return false }
                    return record.id == line.record.id
                }) {
                    items.insert(.rejectedWeightLine(line), at: index + 1)
                } else {
                    items.append(.rejectedWeightLine(line))
                }
            case .insteadOfRecord:
                let index =
                    items.firstIndex { item in
                        guard case .weightRecord(let record) = item else { return false }
                        return record.instant > line.record.instant
                    } ?? items.endIndex
                items.insert(.rejectedWeightLine(line), at: index)
            }
        }
        return items
    }
}
