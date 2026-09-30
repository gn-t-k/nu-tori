public import NuToriAPI
public import NuToriCore

/// アカウントの設定の、メモリのキャッシュに当てる登録簿の1行。アプリの `AccountSettingsRecordKind` と同じ振る舞い
public struct AccountSettingsRecordKindMock: RecordKind {
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
        current: SyncWriteResult.Current?
    ) throws -> KindRejection {
        try core.rejection(of: entry, reason: reason, current: current)
    }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        if let settings = AccountSettingsSyncKind.latestSettings(in: changes) {
            cache.write(settings)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearSettings()
    }

    private let core = AccountSettingsSyncKind()
}
