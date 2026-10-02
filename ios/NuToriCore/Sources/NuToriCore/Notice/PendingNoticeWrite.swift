public import Foundation

/// 知らせの送り待ち。送り待ちの置き場には、知らせの種類の名前と、この中身の JSON で入る
public struct PendingNoticeWrite: Sendable, Equatable {
    public let writeId: UUID
    public let enqueuedAt: Date
    public let write: Write

    public init(writeId: UUID, enqueuedAt: Date, write: Write) {
        self.writeId = writeId
        self.enqueuedAt = enqueuedAt
        self.write = write
    }

    /// 直す・消す書き込みは無い
    public enum Write: Sendable, Equatable {
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
    }

    public init(entry: PendingEntry) throws {
        let content: Content
        do {
            content = try JSONDecoder().decode(Content.self, from: entry.content)
        } catch {
            throw PendingWrite.InvalidEntryError(kind: entry.kind)
        }
        guard let write = content.write() else {
            throw PendingWrite.InvalidEntryError(kind: entry.kind)
        }
        self.init(writeId: entry.writeId, enqueuedAt: entry.enqueuedAt, write: write)
    }

    public func entry() throws -> PendingEntry {
        PendingEntry(
            writeId: writeId,
            enqueuedAt: enqueuedAt,
            kind: NoticeSyncing.kindName,
            content: try JSONEncoder().encode(Content(write))
        )
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    private enum Content: Codable {
        case create(StoredNotice)
        case respond(noticeId: UUID, response: StoredResponse)

        init(_ write: Write) {
            switch write {
            case .create(let notice):
                self = .create(StoredNotice(notice))
            case .respond(let noticeId, let response):
                self = .respond(noticeId: noticeId, response: StoredResponse(response))
            }
        }

        func write() -> Write? {
            switch self {
            case .create(let stored):
                stored.notice().map { .create($0) }
            case .respond(let noticeId, let stored):
                stored.response().map { .respond(noticeId: noticeId, response: $0) }
            }
        }
    }

    private struct StoredNotice: Codable {
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

    private struct StoredResponse: Codable {
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
