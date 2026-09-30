import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("メモリの送り待ちの箱")
struct MemorySyncBoxTests {
    typealias Box = MemorySyncBox<NoteCache>

    @Suite("記録の変更と送り待ちへの追加を当てるとき")
    struct Enqueuing {
        let box: Box
        let cache: NoteCache
        let entry: PendingEntry

        init() {
            cache = NoteCache()
            box = Box(kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: cache)
            entry = RecordKindMock.entry(recordId: UUID())
        }

        @Test("送り待ちを先に保存し、キャッシュをそのあとに保存すること")
        func savesPendingBeforeCache() async throws {
            try await box.apply(
                SyncBoxResult(
                    enqueuing: [entry],
                    kindChanges: [KindChanges(kind: "note", changes: [.unknown(kind: "note")])]
                ))

            #expect(
                await box.saves == [
                    .pending(added: 1, removed: 0),
                    .cache(changes: 1, afterSequence: nil),
                ])
            #expect(await box.pendingEntries() == [entry])
            #expect(cache.appliedChangeCount == 1)
        }
    }

    @Suite("結果を受け取った送り待ちを当てるとき")
    struct Resolving {
        let box: Box
        let resolved: PendingEntry
        let waiting: PendingEntry

        init() {
            resolved = RecordKindMock.entry(recordId: UUID(), ageSeconds: 10)
            waiting = RecordKindMock.entry(recordId: UUID())
            box = Box(
                kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: NoteCache(),
                pendingEntries: [resolved, waiting])
        }

        @Test("キャッシュに当てたあとに、その送り待ちだけを消すこと")
        func removesResolvedAfterCache() async throws {
            try await box.apply(
                SyncBoxResult(
                    resolvedWriteIds: [resolved.writeId],
                    kindChanges: [KindChanges(kind: "note", changes: [.unknown(kind: "note")])]
                ))

            #expect(
                await box.saves == [
                    .cache(changes: 1, afterSequence: nil),
                    .pending(added: 0, removed: 1),
                ])
            #expect(await box.pendingEntries() == [waiting])
        }
    }

    @Suite("250 件の変更を含む頁を当てるとき")
    struct PullingManyChanges {
        let box: Box
        let cache: NoteCache
        let result: SyncBoxResult

        init() {
            cache = NoteCache()
            box = Box(kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: cache)
            result = SyncBoxResult(
                kindChanges: [
                    KindChanges(
                        kind: "note",
                        changes: Array(repeating: .unknown(kind: "note"), count: 250))
                ],
                pulled: PulledChanges(
                    records: [], removedRecordIds: [], accountSettings: nil,
                    state: .fixture(afterSequence: 7))
            )
        }

        @Test("100 件ずつ分けて保存し、通し番号は最後の保存でだけ書くこと")
        func writesSequenceInLastSave() async throws {
            try await box.apply(result)

            #expect(
                await box.saves == [
                    .cache(changes: 100, afterSequence: nil),
                    .cache(changes: 100, afterSequence: nil),
                    .cache(changes: 50, afterSequence: 7),
                ])
            #expect(cache.appliedChangeCount == 250)
            #expect(await box.state?.afterSequence == 7)
        }
    }

    @Suite("種類が変更を当てるのに失敗したとき")
    struct KindFailing {
        let box: Box
        let result: SyncBoxResult

        init() {
            box = Box(
                kinds: RecordKindRegistry([RecordKindMock.error(.init())]), cache: NoteCache(),
                state: .fixture(afterSequence: 3))
            result = SyncBoxResult(
                kindChanges: [KindChanges(kind: "note", changes: [.unknown(kind: "note")])],
                pulled: PulledChanges(
                    records: [], removedRecordIds: [], accountSettings: nil,
                    state: .fixture(afterSequence: 9))
            )
        }

        @Test("通し番号を進めないこと")
        func keepsSequence() async throws {
            await #expect(throws: RecordKindMock.Failure()) {
                try await box.apply(result)
            }

            #expect(await box.state?.afterSequence == 3)
        }
    }

    @Suite("登録簿に無い種類の変更を渡したとき")
    struct UnknownKind {
        let box: Box

        init() {
            box = Box(kinds: RecordKindRegistry([]), cache: NoteCache())
        }

        @Test("知らない種類だと投げること")
        func throwsUnknownKind() async throws {
            await #expect(throws: UnknownRecordKindError(kind: "note")) {
                try await box.apply(
                    SyncBoxResult(
                        kindChanges: [KindChanges(kind: "note", changes: [.unknown(kind: "note")])]
                    ))
            }
        }
    }

    @Suite("全消去するとき")
    struct Erasing {
        let box: Box
        let cache: NoteCache

        init() {
            cache = NoteCache()
            cache.didApply(3)
            box = Box(
                kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: cache,
                pendingEntries: (0..<250).map { _ in RecordKindMock.entry(recordId: UUID()) },
                state: .fixture(afterSequence: 3))
        }

        @Test("1つの保存で送り待ちを全部消し、そのあとキャッシュと通し番号を空にすること")
        func clearsPendingInOneSave() async throws {
            try await box.eraseAll()

            #expect(await box.saves == [.pendingCleared(count: 250), .cacheCleared])
            #expect(await box.pendingEntries().isEmpty)
            #expect(await box.state == nil)
            #expect(cache.appliedChangeCount == 0)
        }
    }
}
