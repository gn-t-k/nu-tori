import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("置き場を分けたあとの開き方")
struct SwiftDataSyncStoreMigrationTests {
    static let record = WeightRecord(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000101")!,
        kilograms: 70,
        instant: Date(timeIntervalSince1970: 1_700_000_000),
        timeZone: TimeZone(identifier: "Asia/Tokyo")!,
        inputSource: .manual,
        version: 1
    )
    static let write = PendingWrite(
        writeId: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
        enqueuedAt: Date(timeIntervalSince1970: 1_700_000_000),
        operation: .createWeightRecord(record)
    )
    static let healthState = HealthSyncState(
        anchor: HealthAnchor(data: Data([0x07])),
        hasWrittenCachedManualRecords: true
    )

    @Suite("更新して最初に開くとき、今の1つの置き場に送り待ちがあるとき")
    @MainActor
    struct LegacyStoreWithPendingWrites {
        let directory: URL
        let legacyURL: URL
        let store: SwiftDataSyncStore

        init() throws {
            directory = SwiftDataSyncStoreTests.makeDirectory()
            legacyURL = LegacyRecordStore.url(in: directory)
            try SwiftDataSyncStoreMigrationTests.writeLegacyStore(at: legacyURL)
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("送り待ちとヘルスケアの同期の進み具合が、送り待ちの置き場に移ること")
        func carriesPendingWritesAndHealthState() async throws {
            #expect(
                try await store.pendingWritesOldestFirst() == [
                    SwiftDataSyncStoreMigrationTests.write
                ])
            #expect(
                try await store.healthSyncState() == SwiftDataSyncStoreMigrationTests.healthState)
        }

        @Test("キャッシュは空になり、全部取り直すこと")
        func startsWithEmptyCache() async throws {
            #expect(try await store.weightRecords().isEmpty)
            #expect(try await store.syncState() == nil)
        }

        @Test("今の置き場のファイルが消え、失敗としては残さないこと")
        func removesLegacyFiles() {
            #expect(!StoreFiles.exists(at: legacyURL))
            #expect(store.takeRecoveries().isEmpty)
        }
    }

    @Suite("更新して最初に開くとき、今の置き場が移行できない形のとき")
    @MainActor
    struct UnmigratableLegacyStore {
        let legacyURL: URL
        let store: SwiftDataSyncStore

        init() throws {
            let directory = SwiftDataSyncStoreTests.makeDirectory()
            legacyURL = LegacyRecordStore.url(in: directory)
            try FileManager.default.createDirectory(
                at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try SwiftDataSyncStoreTests.writeIncompatibleStore(
                entityName: "CachedPendingWrite", at: legacyURL)
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("送り待ちを捨てて、空で始め、今の置き場を消すこと")
        func discardsAndStartsEmpty() async throws {
            #expect(try await store.pendingWritesOldestFirst().isEmpty)
            #expect(try await store.weightRecords().isEmpty)
            #expect(!StoreFiles.exists(at: legacyURL))
        }

        @Test("対処した失敗として残すこと")
        func keepsRecovery() {
            #expect(store.takeRecoveries() == [.storeRecovery])
        }
    }

    @Suite("キャッシュの置き場の形が合わないとき")
    @MainActor
    struct IncompatibleCache {
        let store: SwiftDataSyncStore

        init() async throws {
            let directory = SwiftDataSyncStoreTests.makeDirectory()
            try await Self.seedPendingWrite(in: directory)
            let cacheDirectory = directory.appending(
                path: "CacheStore", directoryHint: .isDirectory)
            let cacheURL = cacheDirectory.appending(path: "CacheStore.store")
            try StoreFiles.remove(at: cacheURL)
            try SwiftDataSyncStoreTests.writeIncompatibleStore(
                entityName: "CachedWeightRecord", at: cacheURL)
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("送り待ちは残り、キャッシュは空になって取り直しになること")
        func keepsPendingWritesAndEmptiesCache() async throws {
            #expect(
                try await store.pendingWritesOldestFirst() == [
                    SwiftDataSyncStoreMigrationTests.write
                ])
            #expect(try await store.weightRecords().isEmpty)
            #expect(try await store.syncState() == nil)
        }

        @Test("作り直したキャッシュに書けること")
        func canSaveIntoRecreatedCache() async throws {
            try await store.saveSyncState(
                SyncState(
                    afterSequence: 1,
                    hasCompletedInitialPull: false,
                    readableKinds: ["weight-record"],
                    startedOn: nil
                ))

            #expect(try await store.syncState()?.afterSequence == 1)
            #expect(store.takeRecoveries().isEmpty)
        }

        /// 最初の置き場を閉じてから、キャッシュのファイルを差し替える
        private static func seedPendingWrite(in directory: URL) async throws {
            let first = try SwiftDataSyncStore(directory: directory)
            try await first.save(
                SwiftDataSyncStoreMigrationTests.record,
                enqueuing: SwiftDataSyncStoreMigrationTests.write)
        }
    }

    @MainActor
    private static func writeLegacyStore(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: LegacyRecordStoreSchemaV2.self)
        let container = try StoreFiles.container(
            schema: schema, plan: nil, name: "RecordStore", at: url)
        let context = container.mainContext
        context.insert(
            LegacyRecordStoreSchemaV2.CachedPendingWrite(
                writeId: write.writeId,
                enqueuedAt: write.enqueuedAt,
                operationJSON: try PendingWriteRow(write: write).operationJSON
            ))
        context.insert(
            LegacyRecordStoreSchemaV2.CachedHealthSyncState(
                singletonKey: "health-sync-state",
                anchorData: healthState.anchor?.data,
                hasWrittenCachedManualRecords: healthState.hasWrittenCachedManualRecords
            ))
        context.insert(
            LegacyRecordStoreSchemaV2.CachedWeightRecord(
                recordId: record.id,
                kilograms: record.kilograms,
                measuredAt: record.instant,
                timeZoneIdentifier: record.timeZone.identifier,
                version: record.version,
                importedJSON: nil
            ))
        context.insert(
            LegacyRecordStoreSchemaV2.CachedSyncState(
                singletonKey: "sync-state",
                afterSequence: 5,
                hasCompletedInitialPull: true,
                readableKinds: ["weight-record"],
                startedOn: nil
            ))
        try context.save()
    }
}
