import Foundation
import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("記録の置き場に、アカウントの設定とヘルスケアを書く")
struct SwiftDataSyncStoreSavingTests {
    @Suite("アカウントの設定を、送り待ちと一緒に書いたとき")
    @MainActor
    struct SavingAccountSettings {
        let store: SwiftDataSyncStore
        let settings: AccountSettings
        let write: PendingAccountSettingsWrite

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            settings = AccountSettings(
                id: UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!,
                sendsUsageData: false
            )
            write = PendingAccountSettingsWrite(
                writeId: UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!,
                enqueuedAt: Date(timeIntervalSince1970: 1_700_000_000),
                write: .updateAccountSettings(settings)
            )
        }

        @Test("設定と送り待ちが残ること")
        func keepsSettingsAndPendingWrite() async throws {
            try await store.save(settings, enqueuing: write)

            #expect(try await store.accountSettings() == settings)
            #expect(try await store.pendingAccountSettingsWritesOldestFirst() == [write])
        }
    }

    @Suite("ヘルスケアの取り込みを当てたとき")
    @MainActor
    struct ApplyingHealthImport {
        let store: SwiftDataSyncStore
        let record: WeightRecord
        let state: HealthSyncState

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            record = WeightRecord(
                id: UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")!,
                kilograms: 70,
                instant: Date(timeIntervalSince1970: 1_700_000_000),
                timeZone: TimeZone(identifier: "Asia/Tokyo")!,
                inputSource: .manual,
                version: 1
            )
            state = HealthSyncState(
                anchor: HealthAnchor(data: Data([0x01])),
                hasWrittenCachedManualRecords: true
            )
        }

        @Test("まだ書いていなければ、最初の状態であること")
        func startsInitial() async throws {
            #expect(try await store.healthSyncState() == .initial)
            #expect(try await store.weightRecords().isEmpty)
        }

        @Test("記録と送り待ちとアンカーが残ること")
        func keepsRecordsPendingWritesAndAnchor() async throws {
            try await store.apply(
                WeightRecordSyncing().importing(
                    [record], sourceDeletedRecordIds: [], now: { record.instant },
                    healthSyncState: state))

            #expect(try await store.weightRecords() == [record])
            #expect(
                try await store.pendingWritesOldestFirst().map(\.write) == [
                    .createWeightRecord(record)
                ])
            #expect(try await store.healthSyncState() == state)
        }
    }

    @Suite("届いた変更に、アカウントの設定と削除の印があるとき")
    @MainActor
    struct ApplyingPulledChanges {
        let store: SwiftDataSyncStore
        let kept: WeightRecord
        let removed: WeightRecord
        let settings: AccountSettings

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            kept = WeightRecord(
                id: UUID(uuidString: "00000000-0000-4000-8000-0000000000e1")!,
                kilograms: 71,
                instant: Date(timeIntervalSince1970: 1_700_000_100),
                timeZone: TimeZone(identifier: "Asia/Tokyo")!,
                inputSource: .manual,
                version: 1
            )
            removed = WeightRecord(
                id: UUID(uuidString: "00000000-0000-4000-8000-0000000000e2")!,
                kilograms: 72,
                instant: Date(timeIntervalSince1970: 1_700_000_200),
                timeZone: TimeZone(identifier: "Asia/Tokyo")!,
                inputSource: .manual,
                version: 1
            )
            settings = AccountSettings(
                id: UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")!,
                sendsUsageData: true
            )
            try await store.save(
                kept,
                enqueuing: PendingWeightRecordWrite(
                    writeId: UUID(uuidString: "00000000-0000-4000-8000-0000000000b5")!,
                    enqueuedAt: kept.instant,
                    write: .createWeightRecord(kept)
                )
            )
            try await store.save(
                removed,
                enqueuing: PendingWeightRecordWrite(
                    writeId: UUID(uuidString: "00000000-0000-4000-8000-0000000000b6")!,
                    enqueuedAt: removed.instant,
                    write: .createWeightRecord(removed)
                )
            )
        }

        @Test("設定が残り、印の付いた記録が消えること")
        func keepsSettingsAndRemovesRecord() async throws {
            try await store.apply(
                SyncBoxResult(
                    kindChanges: [
                        KindChanges(
                            kind: AccountSettingsSyncKind.kindName,
                            changes: [
                                .accountSettings(
                                    SyncedAccountSettings(
                                        id: settings.id, sendsUsageData: settings.sendsUsageData))
                            ]),
                        KindChanges(
                            kind: WeightRecordSyncing.kindName,
                            changes: [.weightRecordDeletion(recordId: removed.id)]),
                    ],
                    syncState: SyncState(
                        afterSequence: 4,
                        hasCompletedInitialPull: true,
                        readableKinds: [.weightRecord],
                        startedOn: nil
                    )
                )
            )

            #expect(try await store.accountSettings() == settings)
            #expect(try await store.weightRecord(id: removed.id) == nil)
            #expect(try await store.weightRecord(id: kept.id) == kept)
        }
    }

    @Suite("すべて消すとき")
    @MainActor
    struct Erasing {
        let store: SwiftDataSyncStore

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let record = WeightRecord(
                id: UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!,
                kilograms: 73,
                instant: Date(timeIntervalSince1970: 1_700_000_300),
                timeZone: TimeZone(identifier: "Asia/Tokyo")!,
                inputSource: .manual,
                version: 1
            )
            let settings = AccountSettings(
                id: UUID(uuidString: "00000000-0000-4000-8000-0000000000a3")!,
                sendsUsageData: false
            )
            try await store.save(
                record,
                enqueuing: PendingWeightRecordWrite(
                    writeId: UUID(uuidString: "00000000-0000-4000-8000-0000000000b3")!,
                    enqueuedAt: record.instant,
                    write: .createWeightRecord(record)
                )
            )
            try await store.save(
                settings,
                enqueuing: PendingAccountSettingsWrite(
                    writeId: UUID(uuidString: "00000000-0000-4000-8000-0000000000b4")!,
                    enqueuedAt: record.instant,
                    write: .updateAccountSettings(settings)
                )
            )
            try await store.saveSyncState(
                SyncState(
                    afterSequence: 8,
                    hasCompletedInitialPull: true,
                    readableKinds: [.weightRecord],
                    startedOn: nil
                )
            )
            try await store.apply(
                SyncBoxResult(
                    healthSyncState: HealthSyncState(
                        anchor: HealthAnchor(data: Data([0x02])),
                        hasWrittenCachedManualRecords: true
                    )
                )
            )
        }

        @Test("記録、アカウントの設定、送り待ち、同期の状態、ヘルスケアの同期の進み具合が空になること")
        func clearsStoredContents() async throws {
            try await store.eraseAll()

            #expect(try await store.weightRecords().isEmpty)
            #expect(try await store.accountSettings() == nil)
            #expect(try await store.pendingEntries().isEmpty)
            #expect(try await store.syncState() == nil)
            #expect(try await store.healthSyncState() == .initial)
        }
    }
}
