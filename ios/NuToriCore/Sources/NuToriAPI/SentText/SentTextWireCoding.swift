import Foundation

/// 送った文章は消えないので、削除の印を持たない
struct SentTextWireCoding: RecordKindWriteWireCoding {
    let kind = Components.Schemas.RecordKindName.sentText

    var writes: (any RecordKindWriteWireCoding)? { self }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.SentTextPayload.self).syncedSentText)
                .map { .sentText($0) }
        case .deletion, .absence: nil
        }
    }

    func wire(of write: SyncWrite) -> SyncWrite.Wire? {
        if case .createSentText(let writeId, let sentText) = write {
            return .init(
                recordId: sentText.id,
                body: .createSentText(
                    .init(
                        id: writeId.canonicalString,
                        _type: .createSentText,
                        sentText: .init(
                            id: sentText.id.canonicalString,
                            body: sentText.body,
                            sentAt: sentText.sentAt.millisecondsSince1970,
                            timeZone: sentText.timeZone.identifier
                        )
                    )
                ))
        }
        if case .resendSentTextAsConversation(let writeId, let sentTextId) = write {
            return .init(
                recordId: sentTextId,
                body: .resendSentTextAsConversation(
                    .init(
                        id: writeId.canonicalString,
                        _type: .resendSentTextAsConversation,
                        sentTextId: sentTextId.canonicalString
                    )
                ))
        }
        if case .resendSentText(let writeId, let sentTextId) = write {
            return .init(
                recordId: sentTextId,
                body: .resendSentText(
                    .init(
                        id: writeId.canonicalString,
                        _type: .resendSentText,
                        sentTextId: sentTextId.canonicalString
                    )
                ))
        }
        return nil
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .sentText(let sentText) = change {
                return .value(
                    id: sentText.id,
                    record: SyncChange.SentTextPayload(
                        id: sentText.id.canonicalString, body: sentText.body,
                        sentAt: sentText.sentAt.millisecondsSince1970,
                        timeZone: sentText.timeZone.identifier))
            }
            if case .sentTextRemoval(let sentTextId) = change {
                return .deviceOnlyRemoval(id: sentTextId)
            }
            return nil
        }

        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite? {
            if case .createSentText(let write) = wire {
                let sentText = write.sentText
                return .createSentText(
                    writeId: try uuid(write.id),
                    sentText: SyncedSentText(
                        id: try uuid(sentText.id),
                        body: sentText.body,
                        sentAt: date(sentText.sentAt),
                        timeZone: try knownTimeZone(sentText.timeZone)))
            }
            if case .resendSentTextAsConversation(let write) = wire {
                return .resendSentTextAsConversation(
                    writeId: try uuid(write.id), sentTextId: try uuid(write.sentTextId))
            }
            if case .resendSentText(let write) = wire {
                return .resendSentText(
                    writeId: try uuid(write.id), sentTextId: try uuid(write.sentTextId))
            }
            return nil
        }
    #endif
}

extension SyncChange {
    /// 読めない ID・タイムゾーンは nil にする
    struct SentTextPayload: Decodable {
        let id: String
        let body: String
        let sentAt: Int
        let timeZone: String

        var syncedSentText: SyncedSentText? {
            guard let id = UUID(uuidString: id), let timeZone = TimeZone(identifier: timeZone)
            else {
                return nil
            }
            return SyncedSentText(
                id: id, body: body, sentAt: Date(timeIntervalSince1970: Double(sentAt) / 1000),
                timeZone: timeZone)
        }
    }
}

#if DEBUG
    extension SyncChange.SentTextPayload: Encodable {}
#endif
