import Foundation
import NuToriCore
import SwiftData
import Synchronization

/// 端末の記録を2つの SwiftData の置き場に持つ（ADR-0022）。
/// キャッシュ（記録、アカウントの設定、通し番号）はサーバーの写しで、移行を持たない。
/// 送り待ちとヘルスケアの同期の進み具合は失えないので、版つきのスキーマで移行する。
/// 記録を作る・直すときは、送り待ちを先に保存し、キャッシュをそのあとに保存する。
/// 保存はメインのコンテキストでだけ行う。バックグラウンドの ModelActor で保存すると、iOS 26 では `@Query` がデッドロックすることがある
nonisolated final class SwiftDataSyncStore: SyncStore, HealthAnchorStore, @unchecked Sendable {
    /// 画面の `@Query` が読むキャッシュの置き場
    let container: ModelContainer

    struct NotOpened: Error {}

    var recordKinds: [any SyncedRecordKind] {
        kinds.synced
    }

    /// 登録簿の種類（今はアカウントの設定）は送り待ちの箱の道で、無い種類は今の道で当てる
    @MainActor init(
        inMemory: Bool,
        kinds: RecordKindRegistry<ModelContext> = AppRecordKinds.registry
    ) throws {
        self.kinds = kinds
        if inMemory {
            container = try Self.memoryContainer(CacheStoreSchema.schema, plan: nil)
            pendingContainer = try Self.memoryContainer(
                Schema(versionedSchema: PendingStoreSchemaV2.self),
                plan: PendingStoreMigrationPlan.self)
            recoveries = Mutex([])
        } else {
            let opened = try Self.openOnDisk(in: .applicationSupportDirectory)
            container = opened.cache
            pendingContainer = opened.pending
            recoveries = Mutex(opened.recoveries)
        }
    }

    /// `directory` の下に、キャッシュと送り待ちの置き場を作る
    @MainActor init(
        directory: URL,
        kinds: RecordKindRegistry<ModelContext> = AppRecordKinds.registry
    ) throws {
        self.kinds = kinds
        let opened = try Self.openOnDisk(in: directory)
        container = opened.cache
        pendingContainer = opened.pending
        recoveries = Mutex(opened.recoveries)
    }

    /// 開くときに対処した失敗。渡したら空になる
    func takeRecoveries() -> [HandledFailure] {
        recoveries.withLock { failures in
            defer { failures = [] }
            return failures
        }
    }

    func weightRecord(id: UUID) async throws -> WeightRecord? {
        try await onMain { stores in
            try Self.cachedRecord(id: id, in: stores.cache)?.weightRecord()
        }
    }

    func weightRecords() async throws -> [WeightRecord] {
        try await onMain { stores in
            try stores.cache.fetch(FetchDescriptor<CachedWeightRecord>()).compactMap {
                $0.weightRecord()
            }
        }
    }

    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws {
        try await onMain { stores in
            try Self.enqueue(write, in: stores.pending)
            try Self.upsert(record, in: stores.cache)
            try stores.cache.save()
        }
    }

    func accountSettings() async throws -> AccountSettings? {
        try await onMain { stores in
            try CachedAccountSettings.current(in: stores.cache)?.accountSettings()
        }
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws {
        try await onMain { stores in
            try Self.enqueue(write, in: stores.pending)
            try CachedAccountSettings.write(settings, in: stores.cache)
            try stores.cache.save()
        }
    }

    func pendingEntries() async throws -> [PendingEntry] {
        try await onMain { stores in
            let descriptor = FetchDescriptor<PendingWriteRow>(
                sortBy: [SortDescriptor(\.enqueuedAt)])
            return try stores.pending.fetch(descriptor).map { $0.entry() }
        }
    }

    /// 送り待ちに足すものを先に保存し、キャッシュをそのあとに保存し、結果を受け取った送り待ちを最後に消す。
    /// 巻き戻しを先に保存するのは、間で落ちても、送り待ちが残るので次に送って同じ巻き戻しに戻るため
    func apply(_ result: SyncBoxResult) async throws {
        let kinds = kinds
        try await onMain { stores in
            if !result.enqueuing.isEmpty {
                for entry in result.enqueuing {
                    stores.pending.insert(PendingWriteRow(entry: entry))
                }
                try stores.pending.save()
            }
            try Self.applyToCache(result, kinds: kinds, in: stores.cache)
            if !result.resolvedWriteIds.isEmpty {
                let removing = Set(result.resolvedWriteIds)
                for row in try stores.pending.fetch(FetchDescriptor<PendingWriteRow>())
                where removing.contains(row.writeId) {
                    stores.pending.delete(row)
                }
                try stores.pending.save()
            }
        }
    }

    func syncState() async throws -> SyncState? {
        try await onMain { stores in
            try Self.cachedSyncState(in: stores.cache)?.syncState()
        }
    }

    func saveSyncState(_ state: SyncState) async throws {
        try await onMain { stores in
            try Self.write(state, in: stores.cache)
            try stores.cache.save()
        }
    }

    func healthSyncState() async throws -> HealthSyncState {
        try await onMain { stores in
            try Self.healthSyncStateRow(in: stores.pending)?.healthSyncState() ?? .initial
        }
    }

    func saveHealthSyncState(_ state: HealthSyncState) async throws {
        try await onMain { stores in
            try Self.write(state, in: stores.pending)
            try stores.pending.save()
        }
    }

    func applyHealthImport(_ batch: HealthImportBatch) async throws {
        try await onMain { stores in
            // 送り待ちと進み具合を先に保存する。間で落ちても、取り込んだ分は送り待ちに残る
            for write in batch.pendingWrites {
                stores.pending.insert(try PendingWriteRow(write: write))
            }
            try Self.write(batch.state, in: stores.pending)
            try stores.pending.save()
            for record in batch.records {
                try Self.upsert(record, in: stores.cache)
            }
            try stores.cache.save()
        }
    }

    /// 送り待ちの置き場を1つの保存で空にしてから、キャッシュの置き場を空にする
    func eraseAll() async throws {
        let kinds = kinds
        try await onMain { stores in
            try stores.pending.delete(model: PendingWriteRow.self)
            try stores.pending.delete(model: HealthSyncStateRow.self)
            try stores.pending.save()
            try stores.cache.delete(model: CachedWeightRecord.self)
            try stores.cache.delete(model: CachedSyncState.self)
            for kind in kinds.kinds {
                try kind.erase(stores.cache)
            }
            try stores.cache.save()
        }
    }

    func deleteAll() async throws {
        try await onMain { stores in
            try stores.pending.delete(model: HealthSyncStateRow.self)
            try stores.pending.save()
        }
    }

    #if DEBUG
        @MainActor func prepareForUITest(state: SyncState?, pendingWrites: [PendingWrite]) throws {
            let stores = contexts()
            for write in pendingWrites {
                try Self.enqueue(write, in: stores.pending)
            }
            if let state {
                try Self.write(state, in: stores.cache)
            }
            for write in pendingWrites {
                switch write.operation {
                case .createWeightRecord(let record), .correctWeightRecord(let record, previous: _):
                    try Self.upsert(record, in: stores.cache)
                case .updateAccountSettings(let settings):
                    try CachedAccountSettings.write(settings, in: stores.cache)
                case .sourceDeletedWeightRecord:
                    break
                }
            }
            if state != nil || !pendingWrites.isEmpty {
                try stores.cache.save()
            }
        }
    #endif

    private struct Contexts {
        let cache: ModelContext
        let pending: ModelContext
    }

    private let pendingContainer: ModelContainer
    private let kinds: RecordKindRegistry<ModelContext>
    private let recoveries: Mutex<[HandledFailure]>

    private func onMain<T: Sendable>(_ body: @MainActor (Contexts) throws -> T) async throws -> T {
        try await MainActor.run {
            try body(self.contexts())
        }
    }

    @MainActor private func contexts() -> Contexts {
        // 呼び出しのあいだに自動で保存すると、1つの操作が別の保存に分かれる
        let cache = container.mainContext
        cache.autosaveEnabled = false
        let pending = pendingContainer.mainContext
        pending.autosaveEnabled = false
        return Contexts(cache: cache, pending: pending)
    }

    /// 送り待ちを保存する（キャッシュより先）
    @MainActor private static func enqueue(_ write: PendingWrite, in context: ModelContext) throws {
        context.insert(try PendingWriteRow(write: write))
        try context.save()
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

    /// 巻き戻しと登録簿の種類の変更を先に保存し、取りに行った記録と通し番号をそのあとに保存する
    @MainActor private static func applyToCache(
        _ result: SyncBoxResult,
        kinds: RecordKindRegistry<ModelContext>,
        in context: ModelContext
    ) throws {
        if !result.reversions.isEmpty {
            for reversion in result.reversions {
                switch reversion {
                case .restore(let record):
                    try upsert(record, in: context)
                case .remove(let recordId):
                    if let row = try cachedRecord(id: recordId, in: context) {
                        context.delete(row)
                    }
                }
            }
            try context.save()
        }
        // メインのコンテキストを長く止めない。通し番号は最後の保存で書くので、途中で落ちても取り直しで揃う
        let batchSize = 100
        for group in result.kindChanges {
            guard let kind = kinds.kind(named: group.kind) else {
                throw UnknownRecordKindError(kind: group.kind)
            }
            for start in stride(from: 0, to: group.changes.count, by: batchSize) {
                let end = min(start + batchSize, group.changes.count)
                try kind.apply(Array(group.changes[start..<end]), to: context)
                try context.save()
            }
        }
        if let changes = result.pulled {
            try applyPulled(changes, in: context, batchSize: batchSize)
        }
    }

    @MainActor private static func applyPulled(
        _ changes: PulledChanges, in context: ModelContext, batchSize: Int
    ) throws {
        if changes.records.isEmpty {
            try finish(changes, in: context)
            try context.save()
            return
        }
        var start = 0
        while start < changes.records.count {
            let end = min(start + batchSize, changes.records.count)
            for record in changes.records[start..<end] {
                try upsert(record, in: context)
            }
            if end == changes.records.count {
                try finish(changes, in: context)
            }
            try context.save()
            start = end
        }
    }

    @MainActor private static func finish(_ changes: PulledChanges, in context: ModelContext) throws
    {
        for recordId in changes.removedRecordIds {
            if let row = try cachedRecord(id: recordId, in: context) {
                context.delete(row)
            }
        }
        try write(changes.state, in: context)
    }

    @MainActor private static func healthSyncStateRow(in context: ModelContext) throws
        -> HealthSyncStateRow?
    {
        let key = HealthSyncStateRow.onlyKey
        var descriptor = FetchDescriptor<HealthSyncStateRow>(
            predicate: #Predicate { $0.singletonKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 保存は呼び出し側が行う
    @MainActor private static func write(_ state: HealthSyncState, in context: ModelContext) throws
    {
        if let existing = try healthSyncStateRow(in: context) {
            existing.apply(state)
        } else {
            context.insert(HealthSyncStateRow(state))
        }
    }

    private static func memoryContainer(
        _ schema: Schema,
        plan: (any SchemaMigrationPlan.Type)?
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: plan,
            configurations: ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }

    private struct Opened {
        let cache: ModelContainer
        let pending: ModelContainer
        let recoveries: [HandledFailure]
    }

    @MainActor private static func openOnDisk(in directory: URL) throws -> Opened {
        var recoveries: [HandledFailure] = []
        let pending = try openPending(in: directory)
        if pending.archived {
            recoveries.append(.storeRecovery)
        }
        // 今の1つの置き場からは、送り待ちを移してから、キャッシュを開く（キャッシュは空から取り直す）
        let outcome = try LegacyRecordStore.carryOver(
            from: LegacyRecordStore.url(in: directory), into: pending.container.mainContext)
        if outcome == .discarded {
            recoveries.append(.storeRecovery)
        }
        let cache = try openCache(in: directory)
        return Opened(cache: cache, pending: pending.container, recoveries: recoveries)
    }

    private static func openPending(in directory: URL) throws -> (
        container: ModelContainer, archived: Bool
    ) {
        let url = try storeURL(named: "PendingStore", in: directory)
        return try StoreFiles.openArchivingUnmigratable(
            schema: Schema(versionedSchema: PendingStoreSchemaV2.self),
            plan: PendingStoreMigrationPlan.self,
            name: "PendingStore",
            at: url
        )
    }

    /// 開けないときは、置き場ごと消して作り直す。空のキャッシュは、次の同期で全部取り直す
    private static func openCache(in directory: URL) throws -> ModelContainer {
        let name = "CacheStore"
        let url = try storeURL(named: name, in: directory)
        do {
            return try StoreFiles.container(
                schema: CacheStoreSchema.schema, plan: nil, name: name, at: url)
        } catch {
            do {
                try StoreFiles.remove(at: url)
                return try StoreFiles.container(
                    schema: CacheStoreSchema.schema, plan: nil, name: name, at: url)
            } catch {
                throw NotOpened()
            }
        }
    }

    private static func storeURL(named name: String, in directory: URL) throws -> URL {
        let folder = directory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "\(name).store")
    }
}
