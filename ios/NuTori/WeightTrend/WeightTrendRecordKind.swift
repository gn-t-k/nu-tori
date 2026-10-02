import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 体重の傾向の、登録簿の1行。届いた並びでキャッシュを置き換え、無くなった印で空にする。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`WeightTrendSyncing`）
nonisolated struct WeightTrendRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 日ごとに差し替えず、丸ごと置き換える。届いていなければ何もしない
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        switch syncing.update(from: changes) {
        case .replace(let trend):
            // 同じ日の行は値を書き換え、並びに無い日の行は消す。日は重ならない（unique）ので、消してから足すことはしない
            var rows = Dictionary(
                try cache.fetch(FetchDescriptor<CachedWeightTrendDay>()).map { ($0.day, $0) },
                uniquingKeysWith: { first, _ in first })
            for day in trend.days {
                if let row = rows.removeValue(forKey: day.day.yearMonthDay) {
                    row.kilograms = day.kilograms
                } else {
                    cache.insert(CachedWeightTrendDay(day))
                }
            }
            for row in rows.values {
                cache.delete(row)
            }
        case .clear:
            try cache.delete(model: CachedWeightTrendDay.self)
        case nil:
            break
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedWeightTrendDay.self)
    }

    private let syncing = WeightTrendSyncing()
}
