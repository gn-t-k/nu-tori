import Foundation

/// 傾向はアカウントに1つで、recordId は種類の名前。値は並び全体で、無いことは削除の印でなく `_absence` で届く
struct WeightTrendWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.weightTrend

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.WeightTrendPayload.self).syncedWeightTrend)
                .map { .weightTrend($0) }
        case .absence: .weightTrendAbsence
        case .deletion: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .weightTrend(let trend) = change {
                return .init(
                    form: .value, recordId: kind.rawValue,
                    record: SyncChange.WeightTrendPayload(
                        days: trend.days.map {
                            .init(calendarDay: $0.calendarDay, trendKg: $0.trendKilograms)
                        }))
            }
            if case .weightTrendAbsence = change {
                return .init(form: .absence, recordId: kind.rawValue, record: [String: String]())
            }
            return nil
        }
    #endif
}

extension SyncChange {
    struct WeightTrendPayload: Decodable {
        let days: [Day]

        struct Day: Decodable {
            let calendarDay: String
            let trendKg: Double
        }

        var syncedWeightTrend: SyncedWeightTrend {
            SyncedWeightTrend(
                days: days.map {
                    SyncedWeightTrend.Day(calendarDay: $0.calendarDay, trendKilograms: $0.trendKg)
                })
        }
    }
}

#if DEBUG
    extension SyncChange.WeightTrendPayload: Encodable {}
    extension SyncChange.WeightTrendPayload.Day: Encodable {}
#endif
