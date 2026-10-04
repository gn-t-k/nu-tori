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
    static let write = PendingWeightRecordWrite(
        writeId: UUID(uuidString: "00000000-0000-4000-8000-000000000102")!,
        enqueuedAt: Date(timeIntervalSince1970: 1_700_000_000),
        write: .createWeightRecord(record)
    )
    static let unreadableWriteId = UUID(uuidString: "00000000-0000-4000-8000-000000000104")!
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
                try await store.pendingWeightRecordWritesOldestFirst() == [
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
            // 今の置き場にもある項目（体重記録の kilograms）の型を変える。無い項目だけだと、空の置き場は移行できてしまう
            try SwiftDataSyncStoreTests.writeIncompatibleStore(
                entityName: "CachedWeightRecord", at: legacyURL)
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("送り待ちを捨てて、空で始め、今の置き場を消すこと")
        func discardsAndStartsEmpty() async throws {
            #expect(try await store.pendingWeightRecordWritesOldestFirst().isEmpty)
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
                try await store.pendingWeightRecordWritesOldestFirst() == [
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
                    readableKinds: [.weightRecord],
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

    @Suite("送り待ちの置き場が、版 1（種類の名前を持たない）のとき")
    @MainActor
    struct PendingStoreVersion1 {
        let store: SwiftDataSyncStore

        init() throws {
            let directory = SwiftDataSyncStoreTests.makeDirectory()
            try SwiftDataSyncStoreMigrationTests.writeVersion1PendingStore(in: directory)
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("送り待ちを種類の名前つきで引き継ぎ、中身に直す前の値が残っていても読めること")
        func carriesWritesWithKindNames() async throws {
            #expect(try await store.pendingWeightRecordWritesOldestFirst() == [correction])
            #expect(try await store.pendingEntries().map(\.kind) == [.weightRecord])
            #expect(store.takeRecoveries().isEmpty)
        }

        @Test("ヘルスケアの同期の進み具合も残ること")
        func keepsHealthState() async throws {
            #expect(
                try await store.healthSyncState() == SwiftDataSyncStoreMigrationTests.healthState)
        }

        private let correction = SwiftDataSyncStoreMigrationTests.correction
    }

    @Suite("送り待ちの置き場が版 1 で、中身を読めない送り待ちがあるとき")
    @MainActor
    struct PendingStoreVersion1WithUnreadableRow {
        let store: SwiftDataSyncStore

        init() throws {
            let directory = SwiftDataSyncStoreTests.makeDirectory()
            try SwiftDataSyncStoreMigrationTests.writeVersion1PendingStoreWithUnreadableRow(
                in: directory)
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("読めない送り待ちだけを捨て、読めるものは残すこと")
        func dropsOnlyUnreadableRow() async throws {
            #expect(
                try await store.pendingEntries().map(\.writeId) == [
                    SwiftDataSyncStoreMigrationTests.correction.writeId
                ])
        }

        @Test("対処した失敗として残すこと")
        func keepsRecovery() {
            #expect(store.takeRecoveries() == [.storeRecovery])
        }
    }

    @Suite("送り待ちの置き場が今の版で、知らない種類の名前の送り待ちがあるとき")
    @MainActor
    struct PendingStoreWithUnknownKindName {
        let store: SwiftDataSyncStore

        init() throws {
            let directory = SwiftDataSyncStoreTests.makeDirectory()
            try SwiftDataSyncStoreMigrationTests.writeCurrentPendingStoreWithUnknownKindName(
                in: directory)
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("知らない名前の送り待ちだけを捨て、読めるものは残すこと")
        func dropsOnlyUnknownKindRow() async throws {
            #expect(
                try await store.pendingEntries().map(\.writeId) == [
                    SwiftDataSyncStoreMigrationTests.correction.writeId
                ])
        }

        @Test("対処した失敗として残すこと")
        func keepsRecovery() {
            #expect(store.takeRecoveries() == [.storeRecovery])
        }
    }

    @Suite("更新して最初に開くとき、今の1つの置き場に中身を読めない送り待ちがあるとき")
    @MainActor
    struct LegacyStoreWithUnreadableRow {
        let store: SwiftDataSyncStore

        init() throws {
            let directory = SwiftDataSyncStoreTests.makeDirectory()
            try SwiftDataSyncStoreMigrationTests.writeLegacyStoreWithUnreadableRow(
                at: LegacyRecordStore.url(in: directory))
            store = try SwiftDataSyncStore(directory: directory)
        }

        @Test("読めない送り待ちは移さず、読めるものは移すこと")
        func carriesOnlyReadableRow() async throws {
            #expect(
                try await store.pendingEntries().map(\.writeId) == [
                    SwiftDataSyncStoreMigrationTests.write.writeId
                ])
        }

        @Test("対処した失敗として残すこと")
        func keepsRecovery() {
            #expect(store.takeRecoveries() == [.storeRecovery])
        }
    }

    @Suite("送り待ちの置き場に、直す前の値を持つ中身が残っているとき")
    @MainActor
    struct LeftoverPreviousInContent {
        let store: SwiftDataSyncStore
        let entry: PendingEntry

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let correction = SwiftDataSyncStoreMigrationTests.correction
            entry = PendingEntry(
                writeId: correction.writeId,
                enqueuedAt: correction.enqueuedAt,
                kind: WeightRecordSyncing.kindName,
                content: try SwiftDataSyncStoreMigrationTests.contentWithPrevious(
                    correction.entry().content)
            )
        }

        @Test("置き場の版を上げずに、直す書き込みとして読めること")
        func readsAsCorrection() async throws {
            try await store.apply(SyncBoxResult(enqueuing: [entry]))

            #expect(
                try await store.pendingWeightRecordWritesOldestFirst() == [
                    SwiftDataSyncStoreMigrationTests.correction
                ])
        }
    }

    static let correction = PendingWeightRecordWrite(
        writeId: UUID(uuidString: "00000000-0000-4000-8000-000000000103")!,
        enqueuedAt: Date(timeIntervalSince1970: 1_700_000_100),
        write: .correctWeightRecord(
            WeightRecord(
                id: record.id, kilograms: 69.5, instant: record.instant, timeZone: record.timeZone,
                inputSource: .manual, version: 2))
    )

    /// 以前の版が書いた、直す前の値（`previous`）を持つ中身。今の中身に `previous` を足して作る
    fileprivate static func contentWithPrevious(_ content: Data) throws -> Data {
        var stored = try JSONDecoder().decode(VersionOneCorrectionContent.self, from: content)
        stored.correct.previous = stored.correct.record
        return try JSONEncoder().encode(stored)
    }

    /// 版 1 のスキーマで、送り待ちの置き場のファイルを書く
    @MainActor
    private static func writeVersion1PendingStore(in directory: URL) throws {
        try writeStore(
            version1PendingStoreContainer(in: directory), insertRows: insertVersion1Rows(into:))
    }

    /// 版 1 のスキーマで、中身を読めない送り待ちも入れて、送り待ちの置き場のファイルを書く
    @MainActor
    private static func writeVersion1PendingStoreWithUnreadableRow(in directory: URL) throws {
        try writeStore(version1PendingStoreContainer(in: directory)) { context in
            try insertVersion1Rows(into: context)
            context.insert(
                PendingStoreSchemaV1.PendingWriteRow(
                    writeId: unreadableWriteId,
                    enqueuedAt: correction.enqueuedAt,
                    operationJSON: Data("読めない中身".utf8)
                ))
        }
    }

    /// 今の版のスキーマで、知らない種類の名前（新しい版が書いたもの）の送り待ちも入れて、送り待ちの置き場のファイルを書く
    @MainActor
    private static func writeCurrentPendingStoreWithUnknownKindName(in directory: URL) throws {
        let folder = directory.appending(path: "PendingStore", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = try StoreFiles.container(
            schema: Schema(versionedSchema: PendingStoreSchemaV2.self),
            plan: PendingStoreMigrationPlan.self,
            name: "PendingStore",
            at: folder.appending(path: "PendingStore.store")
        )
        try writeStore(container) { context in
            context.insert(PendingWriteRow(entry: try correction.entry()))
            context.insert(
                PendingWriteRow(
                    writeId: unreadableWriteId,
                    enqueuedAt: correction.enqueuedAt,
                    kind: "meal-photo",
                    content: Data([0x01])
                ))
        }
    }

    @MainActor
    private static func version1PendingStoreContainer(in directory: URL) throws -> ModelContainer {
        let folder = directory.appending(path: "PendingStore", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try StoreFiles.container(
            schema: Schema(versionedSchema: PendingStoreSchemaV1.self),
            plan: nil,
            name: "PendingStore",
            at: folder.appending(path: "PendingStore.store")
        )
    }

    @MainActor
    private static func insertVersion1Rows(into context: ModelContext) throws {
        context.insert(
            PendingStoreSchemaV1.PendingWriteRow(
                writeId: correction.writeId,
                enqueuedAt: correction.enqueuedAt,
                operationJSON: try contentWithPrevious(correction.entry().content)
            ))
        context.insert(
            PendingStoreSchemaV1.HealthSyncStateRow(
                singletonKey: "health-sync-state",
                anchorData: healthState.anchor?.data,
                hasWrittenCachedManualRecords: healthState.hasWrittenCachedManualRecords
            ))
    }

    @MainActor
    private static func writeLegacyStore(at url: URL) throws {
        try writeStore(legacyStoreContainer(at: url), insertRows: insertLegacyRows(into:))
    }

    /// 中身を読めない送り待ちも入れて、今の1つの置き場のファイルを書く
    @MainActor
    private static func writeLegacyStoreWithUnreadableRow(at url: URL) throws {
        try writeStore(legacyStoreContainer(at: url)) { context in
            try insertLegacyRows(into: context)
            context.insert(
                LegacyRecordStoreSchemaV2.CachedPendingWrite(
                    writeId: unreadableWriteId,
                    enqueuedAt: write.enqueuedAt,
                    operationJSON: Data("読めない中身".utf8)
                ))
        }
    }

    @MainActor
    private static func legacyStoreContainer(at url: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: LegacyRecordStoreSchemaV2.self)
        return try StoreFiles.container(schema: schema, plan: nil, name: "RecordStore", at: url)
    }

    @MainActor
    private static func insertLegacyRows(into context: ModelContext) throws {
        context.insert(
            LegacyRecordStoreSchemaV2.CachedPendingWrite(
                writeId: write.writeId,
                enqueuedAt: write.enqueuedAt,
                operationJSON: try write.entry().content
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
                readableKindsVersion: 1,
                startedOn: nil
            ))
    }

    /// コンテキストはコンテナを保たず、コンテナが先に解放されると行を入れたときに落ちるので、保存し終えるまでコンテナを生かす
    @MainActor
    private static func writeStore(
        _ container: ModelContainer, insertRows: @MainActor (ModelContext) throws -> Void
    ) throws {
        try withExtendedLifetime(container) {
            try insertRows(container.mainContext)
            try container.mainContext.save()
        }
    }
}

/// 版 1 が書いた、手で入れた記録を直す書き込みの JSON の形（固めた写し。今の中身の型は使わない）
private struct VersionOneCorrectionContent: Codable {
    var correct: Body

    struct Body: Codable {
        let record: Record
        var previous: Record?
    }

    struct Record: Codable {
        let id: UUID
        let kilograms: Double
        let measuredAt: Date
        let timeZoneIdentifier: String
        let version: Int
    }
}
