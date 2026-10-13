import NuToriCore
import SwiftData

/// SwiftData の、体重の傾向のキャッシュ。傾向は1件だけの記録で、行は1日に1つ（`CachedWeightTrendDay`）。
/// 保存は箱（`SwiftDataSyncStore`）がメインのコンテキストで行う
nonisolated struct SwiftDataWeightTrendCache: SingleRecordCache {
    let context: ModelContext

    /// 行が無ければ傾向は無い
    func read() throws -> WeightTrend? {
        CachedWeightTrendDay.weightTrend(
            of: try context.fetch(FetchDescriptor<CachedWeightTrendDay>()))
    }

    /// 同じ日の行は値を書き換え、並びに無い日の行は消す。日は重ならない（unique）ので、消してから足すことはしない
    func write(_ trend: WeightTrend) throws {
        var rows = Dictionary(
            try context.fetch(FetchDescriptor<CachedWeightTrendDay>()).map { ($0.day, $0) },
            uniquingKeysWith: { first, _ in first })
        for day in trend.days {
            if let row = rows.removeValue(forKey: day.day.yearMonthDay) {
                row.kilograms = day.kilograms
            } else {
                context.insert(CachedWeightTrendDay(day))
            }
        }
        for row in rows.values {
            context.delete(row)
        }
    }

    func clear() throws {
        try context.deleteAll(CachedWeightTrendDay.self)
    }
}
