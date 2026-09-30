import Foundation
import NuToriCore

/// SwiftData の保存ができるまでの置き場。記録は持てないので、記録の書き込みは投げる。アカウントの設定とヘルスケアの取り込みは、置き場が無いので書いても残らない
nonisolated struct PlaceholderSyncStore: SyncStore {
    let queuedWrites: [PendingWrite]
    let hasCompletedInitialPull: Bool

    func weightRecord(id: UUID) async throws -> WeightRecord? {
        nil
    }

    func weightRecords() async throws -> [WeightRecord] {
        []
    }

    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws {
        throw StoreNotAvailableError()
    }

    func accountSettings() async throws -> AccountSettings? {
        nil
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws {}

    func pendingWritesOldestFirst() async throws -> [PendingWrite] {
        queuedWrites
    }

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws
    {
        throw StoreNotAvailableError()
    }

    func syncState() async throws -> SyncState? {
        SyncState(
            afterSequence: 0,
            hasCompletedInitialPull: hasCompletedInitialPull,
            readableKindsVersion: 0,
            startedOn: nil
        )
    }

    func saveSyncState(_ state: SyncState) async throws {
        throw StoreNotAvailableError()
    }

    func apply(_ changes: PulledChanges) async throws {
        throw StoreNotAvailableError()
    }

    func healthSyncState() async throws -> HealthSyncState {
        .initial
    }

    func saveHealthSyncState(_ state: HealthSyncState) async throws {}

    func applyHealthImport(_ batch: HealthImportBatch) async throws {}

    func eraseAll() async throws {}

    struct StoreNotAvailableError: Error {}
}
