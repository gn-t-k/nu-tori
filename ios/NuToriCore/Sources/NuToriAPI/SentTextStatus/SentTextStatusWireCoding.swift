import Foundation

/// recordId は送った文章の ID。送った文章より先に届くことがある
struct SentTextStatusWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.sentTextStatus

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.SentTextStatusPayload.self).syncedStatus)
                .map { .sentTextStatus($0) }
        case .deletion, .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .sentTextStatus(let status) = change else { return nil }
            return .value(
                id: status.sentTextId,
                record: SyncChange.SentTextStatusPayload(
                    sentTextId: status.sentTextId.canonicalString,
                    classification: status.classification.rawValue,
                    replyStatus: status.reply.serverValue.status,
                    replyFailureReason: status.reply.serverValue.failureReason))
        }
    #endif
}

extension SyncChange {
    /// 知らない読み分けの結果・応答の状態・作れなかった理由は nil にする。サーバーが値を足しても、古い版のアプリは前の状態のまま同期を続ける
    struct SentTextStatusPayload: Decodable {
        let sentTextId: String
        let classification: String
        let replyStatus: String
        /// replyStatus が failed のときだけある
        let replyFailureReason: String?

        var syncedStatus: SyncedSentTextStatus? {
            guard let sentTextId = UUID(uuidString: sentTextId),
                let classification = SyncedSentTextStatus.Classification(rawValue: classification),
                let reply
            else {
                return nil
            }
            return SyncedSentTextStatus(
                sentTextId: sentTextId, classification: classification, reply: reply)
        }

        private var reply: SyncedSentTextStatus.Reply? {
            SyncedSentTextStatus.Reply(serverStatus: replyStatus, failureReason: replyFailureReason)
        }
    }
}

#if DEBUG
    extension SyncChange.SentTextStatusPayload: Encodable {}
#endif
