import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// アカウントの設定の、登録簿の1行。取りに行った設定をキャッシュに当てる。
/// 送る書き込みの形と、変更の見分け方は `AccountSettingsSyncKind`（NuToriCore）
nonisolated struct AccountSettingsRecordKind: RecordKind {
    var name: RecordKindName { core.name }

    func owns(_ change: SyncChange) -> Bool {
        core.owns(change)
    }

    func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        try core.syncWrite(for: entry)
    }

    func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?
    ) throws -> KindRejection {
        try core.rejection(of: entry, reason: reason, current: current)
    }

    /// 届いたなかでいちばん新しい設定を置く。設定の無い取得は、今の設定を変えない
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        guard let settings = AccountSettingsSyncKind.latestSettings(in: changes) else {
            return
        }
        try CachedAccountSettings.write(settings, in: cache)
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedAccountSettings.self)
    }

    private let core = AccountSettingsSyncKind()
}
