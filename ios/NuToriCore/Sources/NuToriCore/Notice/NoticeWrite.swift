public import Foundation

/// 知らせの書き込み。直す・消す書き込みは無い。送り待ちの置き場には、知らせの種類の名前と、この中身の JSON で入る
public enum NoticeWrite: PendingWriteBody {
    /// 答えていない形の知らせを作る
    case create(Notice)
    case respond(noticeId: UUID, response: Notice.Response)

    /// 書き込みが指す知らせの ID
    public var noticeId: UUID {
        switch self {
        case .create(let notice): notice.id
        case .respond(let noticeId, _): noticeId
        }
    }

    public static var kindName: RecordKindName { NoticeSyncing.kindName }

    public var stored: Stored { Stored(self) }

    public init?(stored: Stored) {
        guard let write = stored.write() else { return nil }
        self = write
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    public enum Stored: Codable {
        case create(StoredNotice)
        case respond(noticeId: UUID, response: StoredResponse)

        init(_ write: NoticeWrite) {
            switch write {
            case .create(let notice):
                self = .create(StoredNotice(notice))
            case .respond(let noticeId, let response):
                self = .respond(noticeId: noticeId, response: StoredResponse(response))
            }
        }

        func write() -> NoticeWrite? {
            switch self {
            case .create(let stored):
                stored.notice().map { .create($0) }
            case .respond(let noticeId, let stored):
                stored.response().map { .respond(noticeId: noticeId, response: $0) }
            }
        }
    }

    public struct StoredNotice: Codable {
        let id: UUID
        /// `Notice.Kind` の rawValue
        let kind: String
        let issuedAt: Date
        let timeZoneIdentifier: String
        /// YYYY-MM-DD
        let targetDay: String

        init(_ notice: Notice) {
            id = notice.id
            kind = notice.kind.rawValue
            issuedAt = notice.issuedAt
            timeZoneIdentifier = notice.timeZone.identifier
            targetDay = notice.targetDay.yearMonthDay
        }

        /// 答えていない形の知らせ
        func notice() -> Notice? {
            guard let kind = Notice.Kind(rawValue: kind),
                let timeZone = TimeZone(identifier: timeZoneIdentifier),
                let targetDay = CalendarDay(yearMonthDay: targetDay)
            else {
                return nil
            }
            return Notice(
                id: id, kind: kind, issuedAt: issuedAt, timeZone: timeZone,
                targetDay: targetDay, response: nil)
        }
    }

    public struct StoredResponse: Codable {
        let respondedAt: Date
        let timeZoneIdentifier: String

        init(_ response: Notice.Response) {
            respondedAt = response.respondedAt
            timeZoneIdentifier = response.timeZone.identifier
        }

        func response() -> Notice.Response? {
            TimeZone(identifier: timeZoneIdentifier).map {
                Notice.Response(respondedAt: respondedAt, timeZone: $0)
            }
        }
    }
}

/// 知らせの送り待ち
public typealias PendingNoticeWrite = Pending<NoticeWrite>
