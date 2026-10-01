public import NuToriAPI
public import NuToriCore

/// アカウントの設定の、メモリのキャッシュに当てる登録簿の1行。アプリの `AccountSettingsRecordKind` と同じ振る舞い
public struct AccountSettingsRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { core }

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
