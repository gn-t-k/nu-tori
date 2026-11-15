import Foundation
import NuToriCore
import Testing

@testable import NuTori

/// 保存しない読み方は、メインスレッドの外で読む（#1027）
@Suite("箱の保存しない読み方")
@MainActor
struct SwiftDataSyncStoreReadingTests {
    @Test("キャッシュの種類を読む本文が、メインスレッドの外で動くこと")
    func readsKindOffMain() async throws {
        let store = try SwiftDataSyncStore(inMemory: true)

        let ranOnMain = try await store.read(WeightRecordSyncing.self) { _ in
            Thread.isMainThread
        }

        #expect(!ranOnMain)
    }

    /// メインで読むと、止めているあいだは読み終えられない
    @Suite("メインスレッドを止めているとき")
    @MainActor
    struct MainBlocked {
        let store: SwiftDataSyncStore

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
        }

        @Test("同期の状態を読み終えること")
        func readsSyncState() {
            let store = store
            #expect(Self.finishesWhileMainIsBlocked { _ = try await store.syncState() })
        }

        @Test("ヘルスケアに書いた料理の控えを読み終えること")
        func readsDishVersions() {
            let store = store
            #expect(
                Self.finishesWhileMainIsBlocked {
                    _ = try await store.dishVersionsWrittenToHealth()
                })
        }

        @Test("送り待ちを読み終えること")
        func readsPendingEntries() {
            let store = store
            #expect(Self.finishesWhileMainIsBlocked { _ = try await store.pendingEntries() })
        }

        @Test("ヘルスケアの同期の進み具合を読み終えること")
        func readsHealthSyncState() {
            let store = store
            #expect(Self.finishesWhileMainIsBlocked { _ = try await store.healthSyncState() })
        }

        /// メインスレッドを止めたまま `work` を裏で走らせ、5秒のうちに成功して終わったか。失敗したら時間切れまで待つ
        private static func finishesWhileMainIsBlocked(
            _ work: @escaping @Sendable () async throws -> Void
        ) -> Bool {
            let succeeded = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    try await work()
                    succeeded.signal()
                } catch {}
            }
            return succeeded.wait(timeout: .now() + 5) == .success
        }
    }

    @Suite("メインで体重記録を保存したあと")
    @MainActor
    struct AfterSaving {
        let store: SwiftDataSyncStore
        let record: WeightRecord

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            record = WeightRecord(
                id: UUID(), kilograms: 70, instant: Date(timeIntervalSince1970: 1_700_000_000),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                inputSource: .manual, version: 1)
            try await store.save(
                record,
                enqueuing: PendingWeightRecordWrite(
                    writeId: UUID(), enqueuedAt: record.instant,
                    write: .createWeightRecord(record)))
        }

        @Test("続けて読めること")
        func readsWhatWasJustSaved() async throws {
            #expect(try await store.weightRecords().map(\.id) == [record.id])
        }
    }
}
