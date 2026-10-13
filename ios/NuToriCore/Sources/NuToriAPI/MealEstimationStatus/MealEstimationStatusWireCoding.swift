import Foundation

/// recordId は食事の ID
struct MealEstimationStatusWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.mealEstimationStatus

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.MealEstimationStatusPayload.self).syncedStatus)
                .map { .mealEstimationStatus($0) }
        case .deletion:
            UUID(uuidString: recordId).map { .mealEstimationStatusDeletion(mealId: $0) }
        case .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .mealEstimationStatus(let status) = change {
                return .value(
                    id: status.mealId,
                    record: SyncChange.MealEstimationStatusPayload(
                        mealId: status.mealId.canonicalString, status: status.status.rawValue))
            }
            if case .mealEstimationStatusDeletion(let mealId) = change {
                return .deletion(id: mealId)
            }
            return nil
        }
    #endif
}

extension SyncChange {
    /// 知らない状態は nil にする。サーバーが状態を足しても、古い版のアプリは前の状態のまま同期を続ける
    struct MealEstimationStatusPayload: Decodable {
        let mealId: String
        let status: String

        var syncedStatus: SyncedMealEstimationStatus? {
            guard let mealId = UUID(uuidString: mealId),
                let status = SyncedMealEstimationStatus.Status(rawValue: status)
            else {
                return nil
            }
            return SyncedMealEstimationStatus(mealId: mealId, status: status)
        }
    }
}

#if DEBUG
    extension SyncChange.MealEstimationStatusPayload: Encodable {}
#endif
