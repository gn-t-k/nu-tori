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

    func read<Syncing: CacheApplying, Value: Sendable>(
        _ kind: Syncing.Type,
        _ body: @Sendable (Syncing.Cache) throws -> Value
    ) async throws -> Value {
        await Task.yield()
        return try await box.read(kind, body)
    }
}
