public import Foundation
public import NuToriAPI

/// 送った文章の状態の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct SentTextStatusSyncing: CacheApplying {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.sentTextStatus

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    /// 送った文章1つの状態
    public struct Status: Sendable, Hashable {
        public let sentTextId: UUID
        public let status: SentTextStatus

        public init(sentTextId: UUID, status: SentTextStatus) {
            self.sentTextId = sentTextId
            self.status = status
        }
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 届いた順に状態を書く。送った文章がまだ無い状態も置く（届く順は約束しない）。状態は消えない。
    /// キャッシュは送った文章の ID で引く
    public func apply(_ changes: [SyncChange], to cache: any KeyedRecordCache<Status, UUID>) throws
    {
        for status in current(from: changes) {
            try cache.upsert(status)
        }
    }

    public func erase(_ cache: any KeyedRecordCache<Status, UUID>) throws {
        try cache.removeAll()
    }

    /// 取りに行った変更を、今の状態の並び（届いた順）にする。送った文章より先に届いた状態も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> [Status] {
        changes.compactMap { change in
            guard case .sentTextStatus(let synced) = change else { return nil }
            return Status(sentTextId: synced.sentTextId, status: SentTextStatus(synced))
        }
    }
}

extension SentTextStatus {
    init(_ status: SyncedSentTextStatus) {
        self.init(classification: Classification(status.classification), reply: Reply(status.reply))
    }
}

extension SentTextStatus.Classification {
    init(_ classification: SyncedSentTextStatus.Classification) {
        self =
            switch classification {
            case .pending: .pending
            case .meal: .meal
            case .conversation: .conversation
            }
    }
}

extension SentTextStatus.Reply {
    init(_ reply: SyncedSentTextStatus.Reply) {
        self =
            switch reply {
            case .notRequested: .notRequested
            case .awaiting: .awaiting
            case .replied: .replied
            case .halted(.dailyLimit): .halted(.dailyLimit)
            case .halted(.subscriptionExpired): .halted(.subscriptionExpired)
            case .failed(.retriesExhausted): .failed(.retriesExhausted)
            case .failed(.badRequest): .failed(.badRequest)
            }
    }
}

extension SyncedSentTextStatus.Classification {
    init(_ classification: SentTextStatus.Classification) {
        self =
            switch classification {
            case .pending: .pending
            case .meal: .meal
            case .conversation: .conversation
            }
    }
}

extension SyncedSentTextStatus.Reply {
    init(_ reply: SentTextStatus.Reply) {
        self =
            switch reply {
            case .notRequested: .notRequested
            case .awaiting: .awaiting
            case .replied: .replied
            case .halted(.dailyLimit): .halted(.dailyLimit)
            case .halted(.subscriptionExpired): .halted(.subscriptionExpired)
            case .failed(.retriesExhausted): .failed(.retriesExhausted)
            case .failed(.badRequest): .failed(.badRequest)
            }
    }
}

extension SentTextStatusSyncing.Status: ParentKeyedStatus {
    public var parentId: UUID { sentTextId }
}
