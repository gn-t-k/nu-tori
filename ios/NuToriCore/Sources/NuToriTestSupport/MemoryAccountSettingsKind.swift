public import Foundation
public import NuToriAPI
public import NuToriCore

/// アカウントの設定の、メモリのキャッシュに当てる登録簿の1行。アプリの `AccountSettingsRecordKind` と同じ振る舞い
public struct MemoryAccountSettingsKind: RecordKind {
    public init() {}

    public var name: String { core.name }

    public func owns(_ change: SyncChange) -> Bool {
        core.owns(change)
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        try core.syncWrite(for: entry)
    }

    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        revertedRecordIds: inout Set<UUID>
    ) throws -> KindRejection {
        try core.rejection(of: entry, reason: reason, revertedRecordIds: &revertedRecordIds)
    }

    public func apply(_ changes: [SyncChange], to cache: MemoryRecordCache) throws {
        if let settings = AccountSettingsSyncKind.latestSettings(in: changes) {
            cache.write(settings)
        }
    }

    public func erase(_ cache: MemoryRecordCache) throws {
        cache.clearSettings()
    }

    private let core = AccountSettingsSyncKind()
}
