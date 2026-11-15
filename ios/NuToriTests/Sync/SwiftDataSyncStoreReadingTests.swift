import Foundation
import NuToriCore
import Testing

@testable import NuTori

/// 保存しない読み方は、メインスレッドの外で読む（#1027）。
/// メインスレッドを止めたまま読み終えられるかで確かめる。メインで読むと、止めているあいだ読み終えられない
@Suite("箱の保存しない読み方")
@MainActor
struct SwiftDataSyncStoreReadingTests {
    let store: SwiftDataSyncStore

    init() throws {
        store = try SwiftDataSyncStore(inMemory: true)
    }

    @Test("キャッシュの種類を読む本文が、メインスレッドの外で動くこと")
    func readsKindOffMain() async throws {
        let ranOnMain = try await store.read(WeightRecordSyncing.self) { _ in
            Thread.isMainThread
        }

        #expect(!ranOnMain)
    }

    @Test("キャッシュの種類を、メインスレッドを止めたまま読み終えること")
    func readsKindWhileMainIsBlocked() {
        let store = store
        #expect(Self.finishesWhileMainIsBlocked { _ = try await store.weightRecords() })
    }

    @Test("同期の状態を、メインスレッドを止めたまま読み終えること")
    func readsSyncStateWhileMainIsBlocked() {
        let store = store
        #expect(Self.finishesWhileMainIsBlocked { _ = try await store.syncState() })
    }

    @Test("ヘルスケアに書いた料理の控えを、メインスレッドを止めたまま読み終えること")
    func readsDishVersionsWhileMainIsBlocked() {
        let store = store
        #expect(
            Self.finishesWhileMainIsBlocked { _ = try await store.dishVersionsWrittenToHealth() })
    }

    @Test("送り待ちを、メインスレッドを止めたまま読み終えること")
    func readsPendingEntriesWhileMainIsBlocked() {
        let store = store
        #expect(Self.finishesWhileMainIsBlocked { _ = try await store.pendingEntries() })
    }

    @Test("ヘルスケアの同期の進み具合を、メインスレッドを止めたまま読み終えること")
    func readsHealthSyncStateWhileMainIsBlocked() {
        let store = store
        #expect(Self.finishesWhileMainIsBlocked { _ = try await store.healthSyncState() })
    }

    @Test("メインで保存した体重記録を、続けて読めること")
    func readsWhatWasJustSaved() async throws {
        let record = WeightRecord(
            id: UUID(), kilograms: 70, instant: Date(timeIntervalSince1970: 1_700_000_000),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), inputSource: .manual,
            version: 1)
        try await store.save(
            record,
            enqueuing: PendingWeightRecordWrite(
                writeId: UUID(), enqueuedAt: record.instant, write: .createWeightRecord(record)))

        #expect(try await store.weightRecords().map(\.id) == [record.id])
    }

    /// メインスレッドを止めたまま `work` を裏で走らせ、5秒のうちに終わったか
    private static func finishesWhileMainIsBlocked(
        _ work: @escaping @Sendable () async throws -> Void
    ) -> Bool {
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            try? await work()
            finished.signal()
        }
        return finished.wait(timeout: .now() + 5) == .success
    }
}
