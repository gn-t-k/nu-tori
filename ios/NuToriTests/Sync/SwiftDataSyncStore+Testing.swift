import Foundation
import NuToriCore

@testable import NuTori

/// テストが、体重記録・アカウントの設定・送り待ちを書く・読むための短い呼び方。
/// 書くのは箱の `apply` の1つに束ね、登録簿の種類が今の値を当てる
extension SwiftDataSyncStore {
    func save(_ record: WeightRecord, enqueuing write: PendingWeightRecordWrite) async throws {
        try await apply(WeightRecordSyncing().saving(record, enqueuing: write))
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingAccountSettingsWrite)
        async throws
    {
        try await apply(AccountSettingsSyncKind().saving(settings, enqueuing: write))
    }

    func saveSyncState(_ state: SyncState) async throws {
        try await apply(SyncBoxResult(syncState: state))
    }

    /// 古い順。送り待ちを体重記録の書き込みとして読む（ほかの種類があると投げる）
    func pendingWeightRecordWritesOldestFirst() async throws -> [PendingWeightRecordWrite] {
        try await pendingEntries().map { try PendingWeightRecordWrite(entry: $0) }
    }

    /// 古い順。送り待ちをアカウントの設定の書き込みとして読む（ほかの種類があると投げる）
    func pendingAccountSettingsWritesOldestFirst() async throws -> [PendingAccountSettingsWrite] {
        try await pendingEntries().map { try PendingAccountSettingsWrite(entry: $0) }
    }
}
