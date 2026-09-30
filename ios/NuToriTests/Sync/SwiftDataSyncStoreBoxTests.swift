import Foundation
import NuToriCore
import Testing

@testable import NuTori

@Suite("送り待ちの箱として結果を当てる")
struct SwiftDataSyncStoreBoxTests {
    static let pulledState = SyncState(
        afterSequence: 9, hasCompletedInitialPull: true, readableKinds: ["note"], startedOn: nil)

    @Suite("登録簿の種類の送り待ちと変更を一緒に当てるとき")
    @MainActor
    struct EnqueuingWithChanges {
        let log: RecordKindMock.Log
        let store: SwiftDataSyncStore
        let entry: PendingEntry

        init() throws {
            log = RecordKindMock.Log()
            store = try SwiftDataSyncStore(
                inMemory: true, kinds: RecordKindRegistry([RecordKindMock.ok(log: log)]))
            entry = RecordKindMock.entry()
        }

        @Test("送り待ちが残り、種類に変更が当たること")
        func keepsEntryAndAppliesChanges() async throws {
            try await store.apply(
                SyncBoxResult(
                    enqueuing: [entry],
                    kindChanges: [KindChanges(kind: "note", changes: [RecordKindMock.change])]
                ))

            #expect(try await store.pendingEntries() == [entry])
            #expect(log.appliedChangeCount == 1)
        }
    }

    @Suite("種類がキャッシュに当てるのに失敗したとき")
    @MainActor
    struct KindFailing {
        let store: SwiftDataSyncStore
        let entry: PendingEntry
        let result: SyncBoxResult

        init() throws {
            store = try SwiftDataSyncStore(
                inMemory: true,
                kinds: RecordKindRegistry([RecordKindMock.error(RecordKindMock.Failure())]))
            entry = RecordKindMock.entry()
            result = SyncBoxResult(
                enqueuing: [entry],
                kindChanges: [KindChanges(kind: "note", changes: [RecordKindMock.change])],
                syncState: SwiftDataSyncStoreBoxTests.pulledState
            )
        }

        @Test("送り待ちは先に保存されていること")
        func pendingIsSavedBeforeCache() async throws {
            await #expect(throws: RecordKindMock.Failure()) {
                try await store.apply(result)
            }

            #expect(try await store.pendingEntries() == [entry])
        }

        @Test("通し番号は進まないこと")
        func sequenceDoesNotAdvance() async throws {
            await #expect(throws: RecordKindMock.Failure()) {
                try await store.apply(result)
            }

            #expect(try await store.syncState() == nil)
        }
    }

    @Suite("結果を受け取った送り待ちを当てるとき")
    @MainActor
    struct Resolving {
        let store: SwiftDataSyncStore
        let resolved: PendingEntry
        let waiting: PendingEntry

        init() async throws {
            store = try SwiftDataSyncStore(
                inMemory: true, kinds: RecordKindRegistry([RecordKindMock.ok()]))
            resolved = RecordKindMock.entry(enqueuedAt: Date(timeIntervalSince1970: 1))
            waiting = RecordKindMock.entry(enqueuedAt: Date(timeIntervalSince1970: 2))
            try await store.apply(SyncBoxResult(enqueuing: [waiting, resolved]))
        }

        @Test("その送り待ちだけが消え、古い順に読めること")
        func removesOnlyResolved() async throws {
            try await store.apply(SyncBoxResult(resolvedWriteIds: [resolved.writeId]))

            #expect(try await store.pendingEntries() == [waiting])
        }
    }

    @Suite("250 件の変更を含む頁を当てるとき")
    @MainActor
    struct PullingManyChanges {
        let log: RecordKindMock.Log
        let store: SwiftDataSyncStore

        init() throws {
            log = RecordKindMock.Log()
            store = try SwiftDataSyncStore(
                inMemory: true, kinds: RecordKindRegistry([RecordKindMock.ok(log: log)]))
        }

        @Test("全部当てたあとに、通し番号が進むこと")
        func advancesSequenceAfterAllChanges() async throws {
            try await store.apply(
                SyncBoxResult(
                    kindChanges: [
                        KindChanges(
                            kind: "note",
                            changes: Array(repeating: RecordKindMock.change, count: 250))
                    ],
                    syncState: SwiftDataSyncStoreBoxTests.pulledState
                ))

            #expect(log.appliedChangeCount == 250)
            #expect(try await store.syncState() == SwiftDataSyncStoreBoxTests.pulledState)
        }
    }

    @Suite("全消去するとき")
    @MainActor
    struct Erasing {
        let log: RecordKindMock.Log
        let store: SwiftDataSyncStore

        init() async throws {
            log = RecordKindMock.Log()
            store = try SwiftDataSyncStore(
                inMemory: true, kinds: RecordKindRegistry([RecordKindMock.ok(log: log)]))
            try await store.apply(
                SyncBoxResult(
                    enqueuing: (0..<250).map { index in
                        RecordKindMock.entry(
                            enqueuedAt: Date(timeIntervalSince1970: TimeInterval(index)))
                    },
                    syncState: SwiftDataSyncStoreBoxTests.pulledState
                ))
        }

        @Test("送り待ちを全部消し、種類のキャッシュと通し番号も空にすること")
        func clearsEverything() async throws {
            try await store.eraseAll()

            #expect(try await store.pendingEntries().isEmpty)
            #expect(try await store.syncState() == nil)
            #expect(log.eraseCount == 1)
        }
    }
}
