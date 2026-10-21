import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

// 保存の順そのものは SyncBoxSaveOrderTests で確かめ、ここはメモリの置き場の操作を確かめる
@Suite("メモリの送り待ちの箱")
struct SyncBoxMockTests {
    typealias Box = SyncBoxMock<RecordCacheMock>

    @Suite("記録の変更と送り待ちへの追加を当てるとき")
    struct Enqueuing {
        let box: Box
        let cache: RecordCacheMock
        let entry: PendingEntry

        init() {
            cache = RecordCacheMock()
            box = Box(kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: cache)
            entry = RecordKindMock.entry(recordId: UUID())
        }

        @Test("送り待ちとキャッシュの保存を記録し、送り待ちを持つこと")
        func recordsSavesAndHoldsPending() async throws {
            try await box.apply(
                SyncBoxResult(
                    enqueuing: [entry],
                    kindChanges: [
                        KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")])
                    ]
                ))

            #expect(
                box.saves == [
                    .pending(added: 1, removed: 0),
                    .cache(changes: 1, afterSequence: nil),
                ])
            #expect(try await box.pendingEntries() == [entry])
            #expect(cache.appliedCount(of: .accountSettings) == 1)
        }
    }

    @Suite("ヘルスケアの同期の進み具合を当てるとき")
    struct WritingHealthSyncState {
        let box: Box
        let state: HealthSyncState

        init() {
            box = Box(kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: RecordCacheMock())
            state = HealthSyncState(
                anchor: HealthAnchor(data: Data("anchor".utf8)), hasWrittenCachedManualRecords: true
            )
        }

        @Test("送り待ちと同じ保存で書くこと")
        func savesWithPending() async throws {
            try await box.apply(SyncBoxResult(healthSyncState: state))

            #expect(box.saves == [.pending(added: 0, removed: 0)])
            #expect(box.healthState == state)
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
                kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: RecordCacheMock(),
                pendingEntries: [resolved, waiting])
        }

        @Test("結果を受け取った送り待ちだけを消すこと")
        func removesOnlyResolved() async throws {
            try await box.apply(
                SyncBoxResult(
                    resolvedWriteIds: [resolved.writeId],
                    kindChanges: [
                        KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")])
                    ]
                ))

            #expect(
                box.saves == [
                    .cache(changes: 1, afterSequence: nil),
                    .pending(added: 0, removed: 1),
                ])
            #expect(try await box.pendingEntries() == [waiting])
        }
    }

    @Suite("登録簿にある種類を読むとき")
    struct ReadingRegisteredKind {
        let box: Box
        let record: WeightRecord

        init() throws {
            record = try WeightRecord.manual(
                70.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
            box = try Box.ok(records: [record])
        }

        @Test("登録簿の種類のキャッシュの口から読むこと")
        func readsThroughRegisteredPort() async throws {
            #expect(try await box.read(WeightRecordSyncing.self) { try $0.all() } == [record])
        }
    }

    @Suite("登録簿に無い種類を読むとき")
    struct ReadingUnregisteredKind {
        let box: Box

        init() {
            box = Box(kinds: RecordKindRegistry([]), cache: RecordCacheMock())
        }

        @Test("登録簿に無い種類だと投げること")
        func throwsUnregisteredKind() async throws {
            await #expect(throws: UnknownRecordKindError.notRegistered(.weightRecord)) {
                try await box.read(WeightRecordSyncing.self) { try $0.all() }
            }
        }
    }

    @Suite("全消去するとき")
    struct Erasing {
        let box: Box
        let cache: RecordCacheMock

        init() {
            cache = RecordCacheMock()
            cache.didApply(3, forKind: .accountSettings)
            box = Box(
                kinds: RecordKindRegistry([RecordKindMock.ok()]), cache: cache,
                pendingEntries: (0..<250).map { _ in RecordKindMock.entry(recordId: UUID()) },
                state: .fixture(afterSequence: 3))
        }

        @Test("1つの保存で送り待ちを全部消し、そのあとキャッシュと通し番号を空にすること")
        func clearsPendingInOneSave() async throws {
            try await box.eraseAll()

            #expect(box.saves == [.pendingCleared(count: 250), .cacheCleared])
            #expect(try await box.pendingEntries().isEmpty)
            #expect(box.state == nil)
            #expect(cache.appliedCount(of: .accountSettings) == 0)
        }
    }
}
