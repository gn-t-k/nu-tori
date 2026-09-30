import Foundation
import NuToriCore
import Testing

@testable import NuTori

@Suite("アカウントの設定")
struct AccountSettingsStore {
    @Suite("保存したとき")
    @MainActor
    struct Saved {
        let store: SwiftDataSyncStore
        let settings: AccountSettings
        let write: PendingWrite

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            settings = AccountSettings(id: AccountSettingsStore.settingsId, sendsUsageData: false)
            write = PendingWrite(
                writeId: AccountSettingsStore.writeId,
                enqueuedAt: AccountSettingsStore.enqueuedAt,
                operation: .updateAccountSettings(settings)
            )
        }

        @Test("設定と送り待ちが残ること")
        func keepsSettingsAndPendingWrite() async throws {
            try await store.save(settings, enqueuing: write)
            #expect(try await store.accountSettings() == settings)
            #expect(try await store.pendingWritesOldestFirst() == [write])
        }
    }

    @Suite("設定が届いたあとに、設定の無い取得が来たとき")
    @MainActor
    struct ArrivedThenMissing {
        let store: SwiftDataSyncStore
        let arrived: AccountSettings
        let arrivedChanges: PulledChanges
        let missingChanges: PulledChanges

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let previous = AccountSettings(
                id: AccountSettingsStore.settingsId, sendsUsageData: false)
            try await store.save(
                previous,
                enqueuing: PendingWrite(
                    writeId: AccountSettingsStore.writeId,
                    enqueuedAt: AccountSettingsStore.enqueuedAt,
                    operation: .updateAccountSettings(previous)
                )
            )
            arrived = AccountSettings(id: AccountSettingsStore.settingsId, sendsUsageData: true)
            arrivedChanges = PulledChanges(
                records: [],
                removedRecordIds: [],
                accountSettings: arrived,
                state: SyncState(
                    afterSequence: 1,
                    hasCompletedInitialPull: true,
                    readableKinds: ["weight-record"],
                    startedOn: nil
                )
            )
            missingChanges = PulledChanges(
                records: [],
                removedRecordIds: [],
                accountSettings: nil,
                state: SyncState(
                    afterSequence: 2,
                    hasCompletedInitialPull: true,
                    readableKinds: ["weight-record"],
                    startedOn: nil
                )
            )
        }

        @Test("届いた設定が残ること")
        func keepsArrivedSettings() async throws {
            try await store.apply(arrivedChanges)
            try await store.apply(missingChanges)
            #expect(try await store.accountSettings() == arrived)
        }
    }

    @Suite("すべて消したとき")
    @MainActor
    struct Erased {
        let store: SwiftDataSyncStore

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let settings = AccountSettings(
                id: AccountSettingsStore.settingsId, sendsUsageData: false)
            try await store.save(
                settings,
                enqueuing: PendingWrite(
                    writeId: AccountSettingsStore.writeId,
                    enqueuedAt: AccountSettingsStore.enqueuedAt,
                    operation: .updateAccountSettings(settings)
                )
            )
        }

        @Test("設定も送り待ちも残らないこと")
        func clearsSettingsAndPendingWrites() async throws {
            try await store.eraseAll()
            #expect(try await store.accountSettings() == nil)
            #expect(try await store.pendingWritesOldestFirst().isEmpty)
        }
    }

    private static let settingsId = UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!
    private static let writeId = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!
    private static let enqueuedAt = Date(timeIntervalSince1970: 1_700_000_000)
}
