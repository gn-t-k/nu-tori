import Foundation

/// 返事は消えないので、削除の印を持たない
struct AiUtteranceWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.aiUtterance

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.AiUtterancePayload.self).syncedAiUtterance)
                .map { .aiUtterance($0) }
        case .deletion, .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .aiUtterance(let utterance) = change else { return nil }
            return .value(
                id: utterance.id,
                record: SyncChange.AiUtterancePayload(
                    id: utterance.id.canonicalString, body: utterance.body,
                    sentTextId: utterance.sentTextId.canonicalString,
                    mealIds: utterance.mealIds.map(\.canonicalString)))
        }
    #endif
}

extension SyncChange {
    /// 読めない ID は nil にする
    struct AiUtterancePayload: Decodable {
        let id: String
        let body: String
        let sentTextId: String
        let mealIds: [String]

        var syncedAiUtterance: SyncedAiUtterance? {
            guard let id = UUID(uuidString: id), let sentTextId = UUID(uuidString: sentTextId)
            else {
                return nil
            }
            let mealUUIDs = mealIds.compactMap(UUID.init(uuidString:))
            guard mealUUIDs.count == mealIds.count else { return nil }
            return SyncedAiUtterance(
                id: id, body: body, sentTextId: sentTextId, mealIds: mealUUIDs)
        }
    }
}

#if DEBUG
    extension SyncChange.AiUtterancePayload: Encodable {}
#endif
