import Foundation

/// 日の代表値。その日（記録したときのタイムゾーンでの日付）の、実際の時刻でいちばん早い体重記録。
/// 同じ時刻の記録は ID の順で先のものにし、入力の順に左右されないようにする。
/// サーバーの `computeDailyRepresentativeWeights` と同じ決めごとで、入力と期待値は `shared/daily-representative-weight.test-cases.json`
public struct RepresentativeWeight: Hashable, Sendable {
    public let record: WeightRecord
    /// 同じ日の、代表のほかの体重記録の数
    public let otherRecordCount: Int

    public var day: CalendarDay {
        record.day
    }

    /// 体重記録を日ごとに分け、日の代表値を日の順に返す
    public static func daily(of records: [WeightRecord]) -> [RepresentativeWeight] {
        Dictionary(grouping: records, by: \.day)
            .values
            .compactMap { RepresentativeWeight(sameDayRecords: $0) }
            .sorted { $0.day < $1.day }
    }

    init?(sameDayRecords records: [WeightRecord]) {
        guard
            let first = records.min(by: {
                ($0.instant, $0.id.uuidString) < ($1.instant, $1.id.uuidString)
            })
        else {
            return nil
        }
        record = first
        otherRecordCount = records.count - 1
    }
}
