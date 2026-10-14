import Foundation

/// 1日の目安は消えないので、削除の印を持たない
struct DailyGuideWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.dailyGuide

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.DailyGuidePayload.self).syncedDailyGuide)
                .map { .dailyGuide($0) }
        case .deletion, .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .dailyGuide(let guide) = change else { return nil }
            return .value(id: guide.id, record: SyncChange.DailyGuidePayload(guide))
        }
    #endif
}

extension SyncChange {
    /// 読めない ID は nil にする
    struct DailyGuidePayload: Decodable {
        let id: String
        let goalId: String
        let expenditureEstimateId: String
        let effectiveOn: String
        let energyKcal: Int
        let proteinG: Int
        let fatG: Int
        let carbohydrateG: Int
        let limitHits: [String]

        var syncedDailyGuide: SyncedDailyGuide? {
            guard let id = UUID(uuidString: id), let goalId = UUID(uuidString: goalId),
                let expenditureEstimateId = UUID(uuidString: expenditureEstimateId)
            else {
                return nil
            }
            return SyncedDailyGuide(
                id: id,
                goalId: goalId,
                expenditureEstimateId: expenditureEstimateId,
                effectiveOn: effectiveOn,
                energyKilocalories: energyKcal,
                proteinGrams: proteinG,
                fatGrams: fatG,
                carbohydrateGrams: carbohydrateG,
                // 知らない上限・下限は外して、目安は読む。サーバーが値を足しても、古い版のアプリが1日の丸を目安と比べ続けるため
                limitHits: limitHits.compactMap(SyncedDailyGuide.LimitHit.init(rawValue:))
            )
        }
    }
}

#if DEBUG
    extension SyncChange.DailyGuidePayload: Encodable {
        fileprivate init(_ guide: SyncedDailyGuide) {
            self.init(
                id: guide.id.canonicalString,
                goalId: guide.goalId.canonicalString,
                expenditureEstimateId: guide.expenditureEstimateId.canonicalString,
                effectiveOn: guide.effectiveOn,
                energyKcal: guide.energyKilocalories,
                proteinG: guide.proteinGrams,
                fatG: guide.fatGrams,
                carbohydrateG: guide.carbohydrateGrams,
                limitHits: guide.limitHits.map(\.rawValue)
            )
        }
    }
#endif
