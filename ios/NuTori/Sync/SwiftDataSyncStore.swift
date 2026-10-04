import Foundation
import NuToriAPI
import NuToriCore
import SwiftData
import Synchronization

/// 端末の記録を2つの SwiftData の置き場に持つ（ADR-0022）。
/// キャッシュ（記録、アカウントの設定、通し番号）はサーバーの写しで、移行を持たない。
/// 送り待ちとヘルスケアの同期の進み具合は失えないので、版つきのスキーマで移行する。
/// 記録を作る・直すときは、送り待ちを先に保存し、キャッシュをそのあとに保存する。
/// 保存はメインのコンテキストでだけ行う。バックグラウンドの ModelActor で保存すると、iOS 26 では `@Query` がデッドロックすることがある
nonisolated final class SwiftDataSyncStore: SyncBox, RecordCacheReading, HealthSyncStoring,
    HealthDishWriteStoring, HealthAnchorStore, @unchecked Sendable
{
    /// 画面の `@Query` が読むキャッシュの置き場
    let container: ModelContainer

    /// 置き場を開けなかった。`cause` は開けなかった元のエラー（SwiftData と Foundation のもので、記録の中身は含まない）
    struct NotOpened: Error {
        let cause: any Error
    }

    var recordKinds: [any SyncedRecordKind] {
        kinds.synced
    }

    /// 記録の種類は登録簿（既定はアプリの `AppRecordKinds.registry`）に書く
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
            try CachedWeightRecord.find(id: id, in: stores.cache)?.weightRecord()
        }
    }

    func weightRecords() async throws -> [WeightRecord] {
        try await onMain { stores in
            try stores.cache.fetch(FetchDescriptor<CachedWeightRecord>()).compactMap {
                $0.weightRecord()
            }
        }
    }

    func accountSettings() async throws -> AccountSettings? {
        try await onMain { stores in
            try CachedAccountSettings.current(in: stores.cache)?.accountSettings()
        }
    }

    func mealEstimationStatuses() async throws -> [UUID: MealEstimationStatus] {
        try await onMain { stores in
            var statuses: [UUID: MealEstimationStatus] = [:]
            for row in try stores.cache.fetch(FetchDescriptor<CachedMealEstimationStatus>()) {
                statuses[row.mealId] = row.estimationStatus()
            }
            return statuses
        }
    }

    func meals() async throws -> [Meal] {
        try await onMain { stores in
            try stores.cache.fetch(FetchDescriptor<CachedMeal>()).compactMap { $0.meal() }
        }
    }

    func dishes() async throws -> [Dish] {
        try await onMain { stores in
            try stores.cache.fetch(FetchDescriptor<CachedDish>()).map { $0.dish() }
        }
    }

    func ingredients() async throws -> [Ingredient] {
        try await onMain { stores in
            try stores.cache.fetch(FetchDescriptor<CachedIngredient>()).compactMap {
                $0.ingredient()
            }
        }
    }

    func notices() async throws -> [Notice] {
        try await onMain { stores in
            try stores.cache.fetch(FetchDescriptor<CachedNotice>()).compactMap { $0.notice() }
        }
    }

    func usualWeighingTime() async throws -> UsualWeighingTime? {
        try await onMain { stores in
            try CachedUsualWeighingTime.current(in: stores.cache)?.usualWeighingTime()
        }
    }

    func weightTrend() async throws -> WeightTrend? {
        try await onMain { stores in
            CachedWeightTrendDay.weightTrend(
                of: try stores.cache.fetch(FetchDescriptor<CachedWeightTrendDay>()))
        }
    }

    func dishVersionsWrittenToHealth() async throws -> [UUID: Int] {
        try await onMain { stores in
            let rows = try stores.cache.fetch(FetchDescriptor<CachedHealthDishWrite>())
            return Dictionary(
                rows.map { ($0.dishId, $0.version) }, uniquingKeysWith: { first, _ in first })
        }
    }

    func markDishWrittenToHealth(dishId: UUID, version: Int) async throws {
        try await onMain { stores in
            try CachedHealthDishWrite.mark(dishId: dishId, version: version, in: stores.cache)
            try stores.cache.save()
        }
    }

    func unmarkDishWrittenToHealth(dishId: UUID) async throws {
        try await onMain { stores in
            try CachedHealthDishWrite.unmark(dishId: dishId, in: stores.cache)
            try stores.cache.save()
        }
    }

    func pendingEntries() async throws -> [PendingEntry] {
        try await onMain { stores in
            let descriptor = FetchDescriptor<PendingWriteRow>(
                sortBy: [SortDescriptor(\.enqueuedAt)])
            return try stores.pending.fetch(descriptor).compactMap(\.entry)
        }
    }

    func apply(_ result: SyncBoxResult) async throws {
        let kinds = kinds
        try await onMain { stores in
            try Self.apply(result, kinds: kinds, to: stores)
        }
    }

    func syncState() async throws -> SyncState? {
        try await onMain { stores in
            try Self.cachedSyncState(in: stores.cache)?.syncState()
        }
    }

    func healthSyncState() async throws -> HealthSyncState {
        try await onMain { stores in
            try Self.healthSyncStateRow(in: stores.pending)?.healthSyncState() ?? .initial
        }
    }

    /// 送り待ちの置き場を1つの保存で空にしてから、キャッシュの置き場を空にする
    func eraseAll() async throws {
        let kinds = kinds
        try await onMain { stores in
            try stores.pending.delete(model: PendingWriteRow.self)
            try stores.pending.delete(model: HealthSyncStateRow.self)
            try stores.pending.save()
            try stores.cache.delete(model: CachedSyncState.self)
            try stores.cache.delete(model: CachedHealthDishWrite.self)
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
        /// UI テストが始める前の置き場を、箱と同じ道（`apply`）で作る
        @MainActor func prepareForUITest(_ results: [SyncBoxResult]) throws {
            let stores = contexts()
            for result in results {
                try Self.apply(result, kinds: kinds, to: stores)
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

    /// 送り待ちに足すものと進み具合を先に1つの保存で書き、キャッシュをそのあとに保存し、結果を受け取った送り待ちを最後に消す。
    /// 取り込みの間で落ちても、取り込んだ分は送り待ちに残る。
    /// 受け付けなかった書き込みの戻しは、キャッシュに当てたあとに送り待ちを消す。間で落ちても、送り待ちが残るので次に送って同じ戻しに戻る
    @MainActor private static func apply(
        _ result: SyncBoxResult,
        kinds: RecordKindRegistry<ModelContext>,
        to stores: Contexts
    ) throws {
        if !result.enqueuing.isEmpty || result.healthSyncState != nil {
            for entry in result.enqueuing {
                stores.pending.insert(PendingWriteRow(entry: entry))
            }
            if let healthSyncState = result.healthSyncState {
                try write(healthSyncState, in: stores.pending)
            }
            try stores.pending.save()
        }
        try applyToCache(result, kinds: kinds, in: stores.cache)
        if !result.resolvedWriteIds.isEmpty {
            let removing = Set(result.resolvedWriteIds)
            for row in try stores.pending.fetch(FetchDescriptor<PendingWriteRow>())
            where removing.contains(row.writeId) {
                stores.pending.delete(row)
            }
            try stores.pending.save()
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

    /// 登録簿の種類の変更を100件ずつ保存し、通し番号は最後の保存で書く。途中で落ちても、書いていない変更を追い越さない
    @MainActor private static func applyToCache(
        _ result: SyncBoxResult,
        kinds: RecordKindRegistry<ModelContext>,
        in context: ModelContext
    ) throws {
        // メインのコンテキストを長く止めないよう、分けて保存する
        let batchSize = 100
        var batches: [(kind: any RecordKind<ModelContext>, changes: [SyncChange])] = []
        for group in result.kindChanges {
            guard let kind = kinds.kind(named: group.kind) else {
                throw UnknownRecordKindError.notRegistered(group.kind)
            }
            for start in stride(from: 0, to: group.changes.count, by: batchSize) {
                let end = min(start + batchSize, group.changes.count)
                batches.append((kind, Array(group.changes[start..<end])))
            }
        }
        for (index, batch) in batches.enumerated() {
            try batch.kind.apply(batch.changes, to: context)
            if index == batches.count - 1, let state = result.syncState {
                try write(state, in: context)
            }
            try context.save()
        }
        if batches.isEmpty, let state = result.syncState {
            try write(state, in: context)
            try context.save()
        }
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
        // 版 1 から移したときに、種類の名前を読めなかった送り待ちは、送る前に捨てる（残すと送るたびに同期が止まる）
        if try PendingStoreMigrationPlan.dropUnreadableRows(in: pending.container.mainContext) {
            recoveries.append(.storeRecovery)
        }
        // 今の1つの置き場からは、送り待ちを移してから、キャッシュを開く（キャッシュは空から取り直す）
        let outcome = try LegacyRecordStore.carryOver(
            from: LegacyRecordStore.url(in: directory), into: pending.container.mainContext)
        switch outcome {
        case .absent, .carriedOver(droppedUnreadable: false):
            break
        case .discarded, .carriedOver(droppedUnreadable: true):
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
                throw NotOpened(cause: error)
            }
        }
    }

    private static func storeURL(named name: String, in directory: URL) throws -> URL {
        let folder = directory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "\(name).store")
    }
}
