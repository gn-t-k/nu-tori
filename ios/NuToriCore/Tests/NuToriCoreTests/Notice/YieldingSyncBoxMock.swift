import Foundation
import NuToriCore
import NuToriTestSupport

/// 読むたびに一度ほかのタスクへ譲る、メモリの送り待ちの箱。
/// 本物の箱は MainActor にあり、読むたびに呼び出し側の actor から離れるので、重なった出来事が読みと書きのあいだに割り込む。
/// `SyncBoxMock` は離れずに返すので、割り込みを確かめるテストではこれで包む
final class YieldingSyncBoxMock: SyncBox, RecordCacheReading {
    let box: SyncBoxMock<RecordCacheMock>

    var recordKinds: [any SyncedRecordKind] { box.recordKinds }

    init(_ box: SyncBoxMock<RecordCacheMock>) {
        self.box = box
    }

    func pendingEntries() async throws -> [PendingEntry] {
        await Task.yield()
        return try await box.pendingEntries()
    }

    func syncState() async throws -> SyncState? {
        await Task.yield()
        return try await box.syncState()
    }

    func apply(_ result: SyncBoxResult) async throws {
        try await box.apply(result)
    }

    func eraseAll() async throws {
        try await box.eraseAll()
    }

    func weightRecord(id: UUID) async throws -> WeightRecord? {
        await Task.yield()
        return try await box.weightRecord(id: id)
    }

    func weightRecords() async throws -> [WeightRecord] {
        await Task.yield()
        return try await box.weightRecords()
    }

    func accountSettings() async throws -> AccountSettings? {
        await Task.yield()
        return try await box.accountSettings()
    }

    func mealEstimationStatuses() async throws -> [UUID: MealEstimationStatus] {
        await Task.yield()
        return try await box.mealEstimationStatuses()
    }

    func meals() async throws -> [Meal] {
        await Task.yield()
        return try await box.meals()
    }

    func dishes() async throws -> [Dish] {
        await Task.yield()
        return try await box.dishes()
    }

    func dishEstimationStatuses() async throws -> [UUID: DishEstimationStatus] {
        await Task.yield()
        return try await box.dishEstimationStatuses()
    }

    func ingredients() async throws -> [Ingredient] {
        await Task.yield()
        return try await box.ingredients()
    }

    func notices() async throws -> [Notice] {
        await Task.yield()
        return try await box.notices()
    }

    func usualWeighingTime() async throws -> UsualWeighingTime? {
        await Task.yield()
        return try await box.usualWeighingTime()
    }

    func weightTrend() async throws -> WeightTrend? {
        await Task.yield()
        return try await box.weightTrend()
    }

    func sentTexts() async throws -> [SentText] {
        await Task.yield()
        return try await box.sentTexts()
    }

    func sentTextStatuses() async throws -> [UUID: SentTextStatus] {
        await Task.yield()
        return try await box.sentTextStatuses()
    }
}
