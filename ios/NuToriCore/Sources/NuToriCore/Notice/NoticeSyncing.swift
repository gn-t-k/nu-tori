public import Foundation
public import NuToriAPI

/// 知らせの同期の形。記録の種類の入口のうち、キャッシュの型に依らない部分。
/// 取りに行った変更の見分け方と今の値の読み方、送り待ちから送る書き込み（作る・答える）を作る
public struct NoticeSyncing: SyncedRecordKind, RecordKindWrites {
    /// 送り待ちの種類の名前。変えると、送り待ちに残った知らせが読めなくなる
    public static let kindName = RecordKindName.notice

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { self }

    /// 取りに行った変更のうち、当てる今の値（届いた順）と、キャッシュから外す知らせの ID
    public struct Current: Sendable, Equatable {
        public let notices: [Notice]
        public let removedNoticeIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let pending = try PendingNoticeWrite(entry: entry)
        switch pending.write {
        case .create(let notice):
            return .createNotice(writeId: pending.writeId, notice: NewNotice(notice))
        case .respond(let noticeId, let response):
            return .respondNotice(
                writeId: pending.writeId, noticeId: noticeId,
                response: SyncedNotice.Response(response))
        }
    }

    /// 知らせはユーザーが作った記録ではないので、受け付けなかった行は出さない。
    /// 値は同期の働きがサーバーの今の値で戻す。サーバーに知らせが無いときは、キャッシュから外す
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?,
        shown: ShownRecords
    ) throws -> KindRejection {
        let pending = try PendingNoticeWrite(entry: entry)
        return KindRejection(
            rejectedWrite: nil,
            removingChanges: [.noticeRemoval(noticeId: pending.write.noticeId)]
        )
    }

    /// 知らせを出したときの結果。作る書き込みを送り待ちに足し、知らせを、取りに行った変更と同じ形でキャッシュに当てる
    public func issuing(_ notice: Notice, enqueuing write: PendingNoticeWrite) throws
        -> SyncBoxResult
    {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [KindChanges(kind: name, changes: [.notice(SyncedNotice(notice))])]
        )
    }

    /// 知らせに答えたときの結果。答える書き込みを送り待ちに足し、答えた形の知らせをキャッシュに当てる
    public func responding(
        to notice: Notice, with response: Notice.Response, enqueuing write: PendingNoticeWrite
    ) throws -> SyncBoxResult {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [
                KindChanges(
                    kind: name, changes: [.notice(SyncedNotice(notice.responded(response)))])
            ]
        )
    }

    /// 取りに行った変更を、今の値の並びにする。対象の日付が読めない知らせは読み飛ばす
    public func current(from changes: [SyncChange]) -> Current {
        var notices: [Notice] = []
        var removedNoticeIds: [UUID] = []
        for change in changes {
            if case .notice(let synced) = change, let notice = Notice(synced) {
                notices.append(notice)
            } else if case .noticeRemoval(let noticeId) = change {
                removedNoticeIds.append(noticeId)
            }
        }
        return Current(notices: notices, removedNoticeIds: removedNoticeIds)
    }
}

extension Notice {
    init?(_ notice: SyncedNotice) {
        guard let targetDay = CalendarDay(yearMonthDay: notice.targetOn) else {
            return nil
        }
        self.init(
            id: notice.id,
            kind: Kind(notice.noticeType),
            issuedAt: notice.issuedAt,
            timeZone: notice.timeZone,
            targetDay: targetDay,
            response: notice.response.map {
                Response(respondedAt: $0.respondedAt, timeZone: $0.timeZone)
            }
        )
    }
}

extension Notice.Kind {
    init(_ noticeType: SyncedNotice.NoticeType) {
        switch noticeType {
        case .missedWeightRecord: self = .missedWeightRecord
        }
    }
}

extension SyncedNotice.NoticeType {
    init(_ kind: Notice.Kind) {
        switch kind {
        case .missedWeightRecord: self = .missedWeightRecord
        }
    }
}

extension SyncedNotice {
    init(_ notice: Notice) {
        self.init(
            id: notice.id,
            noticeType: NoticeType(notice.kind),
            issuedAt: notice.issuedAt,
            timeZone: notice.timeZone,
            targetOn: notice.targetDay.yearMonthDay,
            response: notice.response.map(Response.init)
        )
    }
}

extension SyncedNotice.Response {
    init(_ response: Notice.Response) {
        self.init(respondedAt: response.respondedAt, timeZone: response.timeZone)
    }
}

extension NewNotice {
    init(_ notice: Notice) {
        self.init(
            id: notice.id,
            noticeType: SyncedNotice.NoticeType(notice.kind),
            issuedAt: notice.issuedAt,
            timeZone: notice.timeZone,
            targetOn: notice.targetDay.yearMonthDay
        )
    }
}
