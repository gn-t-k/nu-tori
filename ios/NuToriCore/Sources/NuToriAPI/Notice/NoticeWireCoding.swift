import Foundation

/// 知らせは削除の印を持たない
struct NoticeWireCoding: RecordKindWriteWireCoding {
    let kind = Components.Schemas.RecordKindName.notice

    var writes: (any RecordKindWriteWireCoding)? { self }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.NoticePayload.self).syncedNotice)
                .map { .notice($0) }
        case .deletion, .absence: nil
        }
    }

    func wire(of write: SyncWrite) -> SyncWrite.Wire? {
        if case .createNotice(let writeId, let notice) = write {
            return .init(
                recordId: notice.id,
                body: .createNotice(
                    .init(
                        id: writeId.canonicalString,
                        _type: .createNotice,
                        notice: .init(
                            id: notice.id.canonicalString,
                            noticeType: notice.noticeType.serverName,
                            issuedAt: notice.issuedAt.millisecondsSince1970,
                            timeZone: notice.timeZone.identifier,
                            targetOn: notice.noticeType.targetOn
                        )
                    )
                ))
        }
        if case .respondNotice(let writeId, let noticeId, let response) = write {
            return .init(
                recordId: noticeId,
                body: .respondNotice(
                    .init(
                        id: writeId.canonicalString,
                        _type: .respondNotice,
                        noticeId: noticeId.canonicalString,
                        response: .init(
                            respondedAt: response.respondedAt.millisecondsSince1970,
                            timeZone: response.timeZone.identifier
                        )
                    )
                ))
        }
        return nil
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .notice(let notice) = change {
                return .value(id: notice.id, record: SyncChange.NoticePayload(notice))
            }
            if case .noticeRemoval(let noticeId) = change {
                return .deviceOnlyRemoval(id: noticeId)
            }
            return nil
        }

        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite? {
            if case .createNotice(let write) = wire {
                let notice = write.notice
                guard
                    let noticeType = SyncedNotice.NoticeType(
                        serverName: notice.noticeType, targetOn: notice.targetOn)
                else {
                    throw SentSyncWrites.MalformedBodyError(
                        reason: "知らない知らせの種類か、対象の日付が無い \(notice.noticeType)")
                }
                return .createNotice(
                    writeId: try uuid(write.id),
                    notice: NewNotice(
                        id: try uuid(notice.id),
                        noticeType: noticeType,
                        issuedAt: Date(millisecondsSince1970: notice.issuedAt),
                        timeZone: try knownTimeZone(notice.timeZone)
                    ))
            }
            if case .respondNotice(let write) = wire {
                return .respondNotice(
                    writeId: try uuid(write.id),
                    noticeId: try uuid(write.noticeId),
                    response: SyncedNotice.Response(
                        respondedAt: Date(millisecondsSince1970: write.response.respondedAt),
                        timeZone: try knownTimeZone(write.response.timeZone)))
            }
            return nil
        }
    #endif
}

extension SyncChange {
    /// 知らない種類と、読めない ID・タイムゾーン、対象の日付の無い記録忘れの知らせは nil にする
    struct NoticePayload: Decodable {
        let id: String
        let noticeType: String
        let issuedAt: Int
        let timeZone: String
        /// 記録忘れの知らせだけに付く
        let targetOn: String?
        let response: Response?

        struct Response: Decodable {
            let respondedAt: Int
            let timeZone: String
        }

        var syncedNotice: SyncedNotice? {
            guard let id = UUID(uuidString: id),
                let noticeType = SyncedNotice.NoticeType(
                    serverName: noticeType, targetOn: targetOn),
                let timeZone = TimeZone(identifier: timeZone)
            else {
                return nil
            }
            var syncedResponse: SyncedNotice.Response?
            if let response {
                guard let responseTimeZone = TimeZone(identifier: response.timeZone) else {
                    return nil
                }
                syncedResponse = SyncedNotice.Response(
                    respondedAt: Date(millisecondsSince1970: response.respondedAt),
                    timeZone: responseTimeZone)
            }
            return SyncedNotice(
                id: id,
                noticeType: noticeType,
                issuedAt: Date(millisecondsSince1970: issuedAt),
                timeZone: timeZone,
                response: syncedResponse
            )
        }
    }
}

#if DEBUG
    extension SyncChange.NoticePayload: Encodable {
        fileprivate init(_ notice: SyncedNotice) {
            self.init(
                id: notice.id.canonicalString,
                noticeType: notice.noticeType.serverName,
                issuedAt: notice.issuedAt.millisecondsSince1970,
                timeZone: notice.timeZone.identifier,
                targetOn: notice.noticeType.targetOn,
                response: notice.response.map {
                    .init(
                        respondedAt: $0.respondedAt.millisecondsSince1970,
                        timeZone: $0.timeZone.identifier)
                }
            )
        }
    }
    extension SyncChange.NoticePayload.Response: Encodable {}
#endif
