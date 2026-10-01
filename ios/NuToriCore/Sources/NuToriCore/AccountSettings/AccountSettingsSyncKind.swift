import Foundation
public import NuToriAPI

/// アカウントの設定の、送りと受け取りの入口（キャッシュに依らない部分）。
/// 登録簿の1行（アプリの `AccountSettingsRecordKind`）が、これを使ってキャッシュに当てる
public struct AccountSettingsSyncKind: SyncedRecordKind, RecordKindWrites {
    /// 送り待ちの種類の名前。変えると、送り待ちに残った設定が読めなくなる
    public static let kindName = RecordKindName.accountSettings

    public init() {}

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { self }

    public func owns(_ change: SyncChange) -> Bool {
        if case .accountSettings = change { true } else { false }
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let write = try PendingWrite(entry: entry)
        guard case .updateAccountSettings(let settings) = write.operation else {
            throw PendingWrite.InvalidEntryError(kind: entry.kind)
        }
        return Self.syncWrite(writeId: write.writeId, settings: settings)
    }

    /// サーバーはアカウントの設定を受け付けないことが無いので、戻す先も画面に出すものも無い
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?
    ) throws -> KindRejection {
        KindRejection.none
    }

    /// 設定を直したときの結果。送り待ちに足し、今の値を、取りに行った変更と同じ形でキャッシュに当てる
    public func saving(_ settings: AccountSettings, enqueuing write: PendingWrite) throws
        -> SyncBoxResult
    {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [
                KindChanges(
                    kind: name,
                    changes: [
                        .accountSettings(
                            SyncedAccountSettings(
                                id: settings.id, sendsUsageData: settings.sendsUsageData))
                    ])
            ]
        )
    }

    /// 届いた変更のうち、いちばん新しい設定。無ければ nil
    public static func latestSettings(in changes: [SyncChange]) -> AccountSettings? {
        changes.reduce(nil) { latest, change in
            if case .accountSettings(let settings) = change {
                AccountSettings(id: settings.id, sendsUsageData: settings.sendsUsageData)
            } else {
                latest
            }
        }
    }

    /// 記録が無くても直す書き込みで送る。サーバーが無ければ作る
    static func syncWrite(writeId: UUID, settings: AccountSettings) -> SyncWrite {
        .updateAccountSettings(
            writeId: writeId,
            settings: SyncedAccountSettings(
                id: settings.id, sendsUsageData: settings.sendsUsageData)
        )
    }
}
