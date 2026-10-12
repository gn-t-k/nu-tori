import Foundation

/// recordId は料理の ID
struct DishEstimationStatusWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.dishEstimationStatus

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.DishEstimationStatusPayload.self).syncedStatus)
                .map { .dishEstimationStatus($0) }
        case .deletion:
            UUID(uuidString: recordId).map { .dishEstimationStatusDeletion(dishId: $0) }
        case .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .dishEstimationStatus(let status) = change {
                return .value(
                    id: status.dishId,
                    record: SyncChange.DishEstimationStatusPayload(
                        dishId: status.dishId.canonicalString, status: status.status.rawValue))
            }
            if case .dishEstimationStatusDeletion(let dishId) = change {
                return .deletion(id: dishId)
            }
            return nil
        }
    #endif
}

extension SyncChange {
    /// 知らない状態は nil にする。サーバーが状態を足しても、古い版のアプリは前の状態のまま同期を続ける
    struct DishEstimationStatusPayload: Decodable {
        let dishId: String
        let status: String

        var syncedStatus: SyncedDishEstimationStatus? {
            guard let dishId = UUID(uuidString: dishId),
                let status = SyncedDishEstimationStatus.Status(rawValue: status)
            else {
                return nil
            }
            return SyncedDishEstimationStatus(dishId: dishId, status: status)
        }
    }
}

#if DEBUG
    extension SyncChange.DishEstimationStatusPayload: Encodable {}
#endif
