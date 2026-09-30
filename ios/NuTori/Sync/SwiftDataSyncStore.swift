import CoreData
import Foundation
import NuToriCore
import SwiftData

/// 記録、送り待ち、同期の状態を1つの SwiftData に置く。保存はメインのコンテキストでだけ行う。
/// バックグラウンドの ModelActor で保存すると、iOS 26 では `@Query` がデッドロックすることがある
nonisolated final class SwiftDataSyncStore: SyncStore, HealthAnchorStore, @unchecked Sendable {
    let container: ModelContainer

    struct NotOpened: Error {}

    init(inMemory: Bool) throws {
        if inMemory {
            container = try Self.memoryContainer()
        } else {
            let directory = URL.applicationSupportDirectory.appending(
                path: "RecordStore", directoryHint: .isDirectory)
            container = try Self.openDiskContainer(in: directory)
        }
    }

    init(directory: URL) throws {
        container = try Self.openDiskContainer(in: directory)
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

    func weightRecords() async throws -> [WeightRecord] {
        try await onMain { context in
            try context.fetch(FetchDescriptor<CachedWeightRecord>()).compactMap {
                $0.weightRecord()
            }
        }
    }

    func pendingWritesOldestFirst() async throws -> [PendingWrite] {
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
                try Self.remove(changes.removedRecordIds, in: context)
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
                    try Self.remove(changes.removedRecordIds, in: context)
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
            try context.delete(model: CachedHealthSyncState.self)
            try context.save()
        }
    }

    func healthSyncState() async throws -> HealthSyncState {
        try await onMain { context in
            try Self.cachedHealthSyncState(in: context)?.healthSyncState() ?? .initial
        }
    }

    func saveHealthSyncState(_ state: HealthSyncState) async throws {
        try await onMain { context in
            try Self.write(state, in: context)
            try context.save()
        }
    }

    func applyHealthImport(_ batch: HealthImportBatch) async throws {
        try await onMain { context in
            for record in batch.records {
                try Self.upsert(record, in: context)
            }
            for write in batch.pendingWrites {
                context.insert(try CachedPendingWrite(write: write))
            }
            try Self.write(batch.state, in: context)
            try context.save()
        }
    }

    func deleteAll() async throws {
        try await onMain { context in
            try context.delete(model: CachedHealthSyncState.self)
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
                case .sourceDeletedWeightRecord:
                    break
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
            try existing.apply(record)
        } else {
            context.insert(try CachedWeightRecord(record))
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

    @MainActor private static func remove(_ recordIds: [UUID], in context: ModelContext) throws {
        for recordId in recordIds {
            if let row = try cachedRecord(id: recordId, in: context) {
                context.delete(row)
            }
        }
    }

    @MainActor private static func cachedHealthSyncState(in context: ModelContext) throws
        -> CachedHealthSyncState?
    {
        let key = CachedHealthSyncState.onlyKey
        var descriptor = FetchDescriptor<CachedHealthSyncState>(
            predicate: #Predicate { $0.singletonKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor private static func write(_ state: HealthSyncState, in context: ModelContext) throws
    {
        if let existing = try cachedHealthSyncState(in: context) {
            existing.apply(state)
        } else {
            context.insert(CachedHealthSyncState(state))
        }
    }

    private static func memoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: RecordStoreSchemaV2.self)
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

    private static func openDiskContainer(in directory: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: RecordStoreSchemaV2.self)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "RecordStore.store")
        do {
            return try diskContainer(schema: schema, url: url)
        } catch {
            // 移行できない形は SwiftDataError の backwardMigration・unknownSchema・unknownDataStoreSchema と、Core Data の NSPersistentStoreIncompatibleVersionHashError・NSMigrationError・NSMigrationMissingSourceModelError・NSMigrationMissingMappingModelError・NSInferredMappingModelError・NSStagedMigrationBackwardMigrationError。loadIssueModelContainer はコードを落とすので、版ハッシュが今のスキーマと違うときも同じとみなす
            guard isUnmigratableStoreShape(error, at: url, schema: schema) else {
                throw NotOpened()
            }
            do {
                try archiveStore(at: url)
            } catch {
                throw NotOpened()
            }
            return try diskContainer(schema: schema, url: url)
        }
    }

    private static func isUnmigratableStoreShape(_ error: any Error, at url: URL, schema: Schema)
        -> Bool
    {
        if errorIndicatesMigrationMismatch(error) {
            return true
        }
        guard isLoadIssueModelContainer(error) else {
            return false
        }
        return versionHashesDifferFromCurrentSchema(at: url, schema: schema)
    }

    private static func errorIndicatesMigrationMismatch(_ error: any Error) -> Bool {
        switch error {
        case SwiftDataError.backwardMigration, SwiftDataError.unknownSchema:
            return true
        default:
            break
        }
        if #available(iOS 27, *) {
            if case SwiftDataError.unknownDataStoreSchema = error {
                return true
            }
        }
        let nsError = error as NSError
        let migrationMismatchCodes: Set<Int> = [
            NSPersistentStoreIncompatibleVersionHashError,
            NSMigrationError,
            NSMigrationMissingSourceModelError,
            NSMigrationMissingMappingModelError,
            NSInferredMappingModelError,
            NSStagedMigrationBackwardMigrationError,
        ]
        if nsError.domain == NSCocoaErrorDomain, migrationMismatchCodes.contains(nsError.code) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
            return errorIndicatesMigrationMismatch(underlying)
        }
        return false
    }

    private static func isLoadIssueModelContainer(_ error: any Error) -> Bool {
        switch error {
        case SwiftDataError.loadIssueModelContainer:
            return true
        default:
            return false
        }
    }

    private static func versionHashesDifferFromCurrentSchema(at url: URL, schema: Schema) -> Bool {
        guard let onDisk = storeVersionHashes(at: url) else { return false }
        let reference = FileManager.default.temporaryDirectory.appending(
            path: "RecordStore-schema-\(UUID().uuidString).store")
        defer { removeTemporaryStore(at: reference) }
        do {
            _ = try diskContainer(schema: schema, url: reference)
        } catch {
            return false
        }
        guard let current = storeVersionHashes(at: reference) else { return false }
        return onDisk != current
    }

    private static func storeVersionHashes(at url: URL) -> [String: Data]? {
        guard
            let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: url),
            let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data]
        else {
            return nil
        }
        return hashes
    }

    private static func archiveStore(at url: URL) throws {
        let stamp = archiveStamp(Date())
        let manager = FileManager.default
        var moved: [(URL, URL)] = []
        do {
            for suffix in ["-shm", "-wal", ""] {
                let file = URL(filePath: url.path(percentEncoded: false) + suffix)
                let path = file.path(percentEncoded: false)
                guard manager.fileExists(atPath: path) else { continue }
                let destination = URL(filePath: path + "." + stamp)
                try manager.moveItem(at: file, to: destination)
                moved.append((file, destination))
            }
        } catch {
            for (file, destination) in moved.reversed() {
                try? manager.moveItem(at: destination, to: file)
            }
            throw error
        }
    }

    private static func archiveStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func removeTemporaryStore(at url: URL) {
        let manager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(filePath: url.path(percentEncoded: false) + suffix)
            try? manager.removeItem(at: file)
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
}
