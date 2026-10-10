public import Foundation
public import NuToriAPI

/// 送った文章の状態の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct SentTextStatusSyncing: SyncedRecordKind {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.sentTextStatus

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    /// 送った文章1つの状態
    public struct Status: Sendable, Equatable {
        public let sentTextId: UUID
        public let status: SentTextStatus
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
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
        self.init(
            classification: {
                switch status.classification {
                case .pending: .pending
                case .meal: .meal
                case .conversation: .conversation
                }
            }())
    }
}
