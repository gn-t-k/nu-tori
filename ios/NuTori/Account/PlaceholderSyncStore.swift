import Foundation
import NuToriCore

/// SwiftData の保存ができるまでの置き場。体重の記録は持てない。アカウントの設定は、切り替えがその場で効くよう、このプロセスのあいだだけ持つ
final class PlaceholderSyncStore: SyncStore, @unchecked Sendable {
    init(queuedWrites: [PendingWrite], hasCompletedInitialPull: Bool) {
        self.queuedWrites = queuedWrites
        self.hasCompletedInitialPull = hasCompletedInitialPull
    }

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
        settings
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws {
        self.settings = settings
        queuedWrites.append(write)
    }

    func pendingWritesOldestFirst() async throws -> [PendingWrite] {
        queuedWrites
    }

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws
    {
        throw StoreNotAvailableError()
    }

    func syncState() async throws -> SyncState? {
        guard !didErase else { return nil }
        return SyncState(
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

    func eraseAll() async throws {
        settings = nil
        queuedWrites = []
        didErase = true
    }

    struct StoreNotAvailableError: Error {}

    private var queuedWrites: [PendingWrite]
    private let hasCompletedInitialPull: Bool
    private var settings: AccountSettings?
    private var didErase = false
}
