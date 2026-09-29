import Foundation
import NuToriCore
import SwiftData

/// 記録、送り待ち、同期の状態を1つの SwiftData に置く。保存はメインのコンテキストでだけ行う。
/// バックグラウンドの ModelActor で保存すると、iOS 26 では `@Query` がデッドロックすることがある
nonisolated final class SwiftDataSyncStore: SyncStore, @unchecked Sendable {
    let container: ModelContainer

    init(inMemory: Bool) throws {
        container = try Self.makeContainer(inMemory: inMemory)
    }

    func weightRecord(id: UUID) async throws -> WeightRecord? {
        try await onMain { context in
            try Self.cachedRecord(id: id, in: context)?.weightRecord()
        }
    }

    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws {
        try await onMain { context in
            try Self.upsert(record, in: context)
            context.insert(try CachedPendingWrite(write: write))
            try context.save()
        }
    }

    func pendingWrites() async throws -> [PendingWrite] {
        try await onMain { context in
            let descriptor = FetchDescriptor<CachedPendingWrite>(
                sortBy: [SortDescriptor(\.enqueuedAt)])
            return try context.fetch(descriptor).map { try $0.pendingWrite() }
        }
    }

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws
    {
        try await onMain { context in
            let removing = Set(writeIds)
            let descriptor = FetchDescriptor<CachedPendingWrite>()
            for row in try context.fetch(descriptor) where removing.contains(row.writeId) {
                context.delete(row)
            }
            for reversion in reversions {
                switch reversion {
                case .restore(let record):
                    try Self.upsert(record, in: context)
                case .remove(let recordId):
                    if let row = try Self.cachedRecord(id: recordId, in: context) {
                        context.delete(row)
                    }
                }
            }
            try context.save()
        }
    }

    func syncState() async throws -> SyncState? {
        try await onMain { context in
            try Self.cachedSyncState(in: context)?.syncState()
        }
    }

    func saveSyncState(_ state: SyncState) async throws {
        try await onMain { context in
            try Self.write(state, in: context)
            try context.save()
        }
    }

    func apply(_ changes: PulledChanges) async throws {
        try await onMain { context in
            // メインのコンテキストを長く止めない。最後の保存で通し番号も書くので、途中で落ちても取り直しで揃う
            let batchSize = 100
            if changes.records.isEmpty {
                try Self.write(changes.state, in: context)
                try context.save()
                return
            }
            var start = 0
            while start < changes.records.count {
                let end = min(start + batchSize, changes.records.count)
                for record in changes.records[start..<end] {
                    try Self.upsert(record, in: context)
                }
                if end == changes.records.count {
                    try Self.write(changes.state, in: context)
                }
                try context.save()
                start = end
            }
        }
    }

    func eraseAll() async throws {
        try await onMain { context in
            try context.delete(model: CachedWeightRecord.self)
            try context.delete(model: CachedPendingWrite.self)
            try context.delete(model: CachedSyncState.self)
            try context.save()
        }
    }

    #if DEBUG
        @MainActor func prepareForUITest(state: SyncState?, pendingWrites: [PendingWrite]) throws {
            let context = context()
            if let state {
                try Self.write(state, in: context)
            }
            for write in pendingWrites {
                context.insert(try CachedPendingWrite(write: write))
                switch write.operation {
                case .createWeightRecord(let record), .correctWeightRecord(let record, previous: _):
                    try Self.upsert(record, in: context)
                }
            }
            if state != nil || !pendingWrites.isEmpty {
                try context.save()
            }
        }
    #endif

    private func onMain<T: Sendable>(_ body: @MainActor (ModelContext) throws -> T) async throws
        -> T
    {
        try await MainActor.run {
            try body(self.context())
        }
    }

    @MainActor private func context() -> ModelContext {
        let context = container.mainContext
        // 呼び出しのあいだに自動で保存すると、記録と送り待ちが別の保存に分かれる
        context.autosaveEnabled = false
        return context
    }

    @MainActor private static func cachedRecord(id: UUID, in context: ModelContext) throws
        -> CachedWeightRecord?
    {
        try context.fetch(FetchDescriptor<CachedWeightRecord>()).first { $0.recordId == id }
    }

    @MainActor private static func upsert(_ record: WeightRecord, in context: ModelContext) throws {
        if let existing = try cachedRecord(id: record.id, in: context) {
            existing.apply(record)
        } else {
            context.insert(CachedWeightRecord(record))
        }
    }

    @MainActor private static func cachedSyncState(in context: ModelContext) throws
        -> CachedSyncState?
    {
        let key = CachedSyncState.onlyKey
        var descriptor = FetchDescriptor<CachedSyncState>(
            predicate: #Predicate { $0.singletonKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor private static func write(_ state: SyncState, in context: ModelContext) throws {
        if let existing = try cachedSyncState(in: context) {
            existing.apply(state)
        } else {
            context.insert(CachedSyncState(state))
        }
    }

    private static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema(versionedSchema: RecordStoreSchemaV1.self)
        if inMemory {
            return try ModelContainer(
                for: schema,
                migrationPlan: RecordStoreMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            )
        }
        let url = try storeFileURL()
        do {
            return try diskContainer(schema: schema, url: url)
        } catch {
            // この版の移行の段では開けないファイル。記録を捨てて取り直す。送り待ちも同じファイルなので、このときは残らない
            try removeStore(at: url)
            return try diskContainer(schema: schema, url: url)
        }
    }

    private static func diskContainer(schema: Schema, url: URL) throws -> ModelContainer {
        // ファイルの保護は指定しない。iOS の既定（初回のロック解除のあとは、バックグラウンド更新からも読める）
        try ModelContainer(
            for: schema,
            migrationPlan: RecordStoreMigrationPlan.self,
            configurations: ModelConfiguration(
                "RecordStore",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        )
    }

    private static func storeFileURL() throws -> URL {
        let directory = URL.applicationSupportDirectory.appending(
            path: "RecordStore", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "RecordStore.store")
    }

    private static func removeStore(at url: URL) throws {
        let manager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(filePath: url.path(percentEncoded: false) + suffix)
            if manager.fileExists(atPath: file.path(percentEncoded: false)) {
                try manager.removeItem(at: file)
            }
        }
    }
}
