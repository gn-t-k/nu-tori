import Foundation
import NuToriCore

@testable import NuTori

/// テストが、体重記録・アカウントの設定・送り待ちを書く・読むための短い呼び方。
/// 書くのは箱の `apply` の1つに束ね、登録簿の種類が今の値を当てる
extension SwiftDataSyncStore {
    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws {
        try await apply(WeightRecordSyncing().saving(record, enqueuing: write))
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws {
        try await apply(AccountSettingsSyncKind().saving(settings, enqueuing: write))
    }

    func saveSyncState(_ state: SyncState) async throws {
        try await apply(SyncBoxResult(syncState: state))
    }

    /// 古い順。体重記録とアカウントの設定の送り待ちを、書き込みとして読む
    func pendingWritesOldestFirst() async throws -> [PendingWrite] {
        try await pendingEntries().map { try PendingWrite(entry: $0) }
    }
}
