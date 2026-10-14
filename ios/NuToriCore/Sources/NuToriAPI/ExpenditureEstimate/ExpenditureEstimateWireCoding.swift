import Foundation

/// 推定消費カロリーは消えないので、削除の印を持たない
struct ExpenditureEstimateWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.expenditureEstimate

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.ExpenditureEstimatePayload.self)
                .syncedExpenditureEstimate)
                .map { .expenditureEstimate($0) }
        case .deletion, .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .expenditureEstimate(let estimate) = change else { return nil }
            return .value(
                id: estimate.id,
                record: SyncChange.ExpenditureEstimatePayload(
                    id: estimate.id.canonicalString,
                    effectiveOn: estimate.effectiveOn,
                    expenditureKcal: estimate.expenditureKilocalories,
                    estimatedAt: estimate.estimatedAt.millisecondsSince1970,
                    initialSource: estimate.initialSource?.rawValue))
        }
    #endif
}

extension SyncChange {
    /// 読めない ID と、知らない出どころは nil にする。出どころを落として読むと、推定の始まりでない推定に見えるため
    struct ExpenditureEstimatePayload: Decodable {
        let id: String
        let effectiveOn: String
        let expenditureKcal: Int
        let estimatedAt: Int
        /// 推定の始まりだけに付く
        let initialSource: String?

        var syncedExpenditureEstimate: SyncedExpenditureEstimate? {
            guard let id = UUID(uuidString: id) else { return nil }
            var source: SyncedExpenditureEstimate.InitialSource?
            if let initialSource {
                guard let known = SyncedExpenditureEstimate.InitialSource(rawValue: initialSource)
                else { return nil }
                source = known
            }
            return SyncedExpenditureEstimate(
                id: id,
                effectiveOn: effectiveOn,
                expenditureKilocalories: expenditureKcal,
                estimatedAt: Date(millisecondsSince1970: estimatedAt),
                initialSource: source
            )
        }
    }
}

#if DEBUG
    extension SyncChange.ExpenditureEstimatePayload: Encodable {}
#endif
