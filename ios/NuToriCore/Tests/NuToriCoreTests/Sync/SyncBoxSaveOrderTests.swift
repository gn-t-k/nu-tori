import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("送り待ちの箱の保存の順")
struct SyncBoxSaveOrderTests {
    @Suite("記録の変更と送り待ちへの追加を当てるとき")
    struct Enqueuing {
        let log: SaveLog
        let cache: RecordCacheMock
        let kinds: RecordKindRegistry<RecordCacheMock>
        let entry: PendingEntry

        init() {
            log = SaveLog()
            cache = RecordCacheMock()
            kinds = RecordKindRegistry([RecordKindMock.ok()])
            entry = RecordKindMock.entry(recordId: UUID())
        }

        @Test("送り待ちを先に保存し、キャッシュをそのあとに保存すること")
        func savesPendingBeforeCache() throws {
            try SyncBoxSaveOrder.apply(
                SyncBoxResult(
                    enqueuing: [entry],
                    kindChanges: [
                        KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")])
                    ]
                ),
                kinds: kinds, cache: cache,
                savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                saveCache: {
                    log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                },
                removePending: { log.saves.append(.removingPending(writeIds: $0)) })

            #expect(
                log.saves == [
                    .pending(enqueued: [entry], healthSyncState: nil),
                    .cache(changes: 1, afterSequence: nil),
                ])
            #expect(cache.appliedCount(of: .accountSettings) == 1)
        }
    }

    @Suite("ヘルスケアの同期の進み具合を当てるとき")
    struct WritingHealthSyncState {
        let log: SaveLog
        let cache: RecordCacheMock
        let kinds: RecordKindRegistry<RecordCacheMock>
        let entry: PendingEntry
        let state: HealthSyncState

        init() {
            log = SaveLog()
            cache = RecordCacheMock()
            kinds = RecordKindRegistry([RecordKindMock.ok()])
            entry = RecordKindMock.entry(recordId: UUID())
            state = HealthSyncState(
                anchor: HealthAnchor(data: Data("anchor".utf8)), hasWrittenCachedManualRecords: true
            )
        }

        @Test("送り待ちと同じ保存で、キャッシュより先に書くこと")
        func savesWithPendingBeforeCache() throws {
            try SyncBoxSaveOrder.apply(
                SyncBoxResult(
                    enqueuing: [entry],
                    kindChanges: [
                        KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")])
                    ],
                    healthSyncState: state
                ),
                kinds: kinds, cache: cache,
                savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                saveCache: {
                    log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                },
                removePending: { log.saves.append(.removingPending(writeIds: $0)) })

            #expect(
                log.saves == [
                    .pending(enqueued: [entry], healthSyncState: state),
                    .cache(changes: 1, afterSequence: nil),
                ])
        }

        @Test("送り待ちに足すものが無くても、送り待ちの置き場に書くこと")
        func savesWithoutEnqueuing() throws {
            try SyncBoxSaveOrder.apply(
                SyncBoxResult(healthSyncState: state),
                kinds: kinds, cache: cache,
                savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                saveCache: {
                    log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                },
                removePending: { log.saves.append(.removingPending(writeIds: $0)) })

            #expect(log.saves == [.pending(enqueued: [], healthSyncState: state)])
        }
    }

    @Suite("結果を受け取った送り待ちを当てるとき")
    struct Resolving {
        @Suite("キャッシュを保存できたとき")
        struct CacheSaved {
            let log: SaveLog
            let cache: RecordCacheMock
            let kinds: RecordKindRegistry<RecordCacheMock>
            let resolvedWriteId: UUID
            let result: SyncBoxResult

            init() {
                log = SaveLog()
                cache = RecordCacheMock()
                kinds = RecordKindRegistry([RecordKindMock.ok()])
                resolvedWriteId = UUID()
                result = SyncBoxResult(
                    resolvedWriteIds: [resolvedWriteId],
                    kindChanges: [
                        KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")])
                    ]
                )
            }

            @Test("キャッシュに当てたあとに、その送り待ちを消すこと")
            func removesResolvedAfterCache() throws {
                try SyncBoxSaveOrder.apply(
                    result, kinds: kinds, cache: cache,
                    savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                    saveCache: {
                        log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                    },
                    removePending: { log.saves.append(.removingPending(writeIds: $0)) })

                #expect(
                    log.saves == [
                        .cache(changes: 1, afterSequence: nil),
                        .removingPending(writeIds: [resolvedWriteId]),
                    ])
            }
        }

        @Suite("キャッシュの保存に失敗したとき")
        struct CacheSaveFailing {
            struct Failure: Error, Equatable {}

            let log: SaveLog
            let cache: RecordCacheMock
            let kinds: RecordKindRegistry<RecordCacheMock>
            let result: SyncBoxResult

            init() {
                log = SaveLog()
                cache = RecordCacheMock()
                kinds = RecordKindRegistry([RecordKindMock.ok()])
                result = SyncBoxResult(
                    resolvedWriteIds: [UUID()],
                    kindChanges: [
                        KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")])
                    ]
                )
            }

            @Test("送り待ちを消さないこと")
            func keepsResolved() throws {
                #expect(throws: Failure()) {
                    try SyncBoxSaveOrder.apply(
                        result, kinds: kinds, cache: cache,
                        savePending: {
                            log.saves.append(.pending(enqueued: $0, healthSyncState: $1))
                        },
                        saveCache: { _, _ in throw Failure() },
                        removePending: { log.saves.append(.removingPending(writeIds: $0)) })
                }

                #expect(log.saves.isEmpty)
            }
        }
    }

    @Suite("250 件の変更を含む頁を当てるとき")
    struct PullingManyChanges {
        let log: SaveLog
        let cache: RecordCacheMock
        let kinds: RecordKindRegistry<RecordCacheMock>
        let result: SyncBoxResult

        init() {
            log = SaveLog()
            cache = RecordCacheMock()
            kinds = RecordKindRegistry([RecordKindMock.ok()])
            result = SyncBoxResult(
                kindChanges: [
                    KindChanges(
                        kind: .accountSettings,
                        changes: Array(repeating: .unknown(kind: "note"), count: 250))
                ],
                syncState: .fixture(afterSequence: 7)
            )
        }

        @Test("100 件ずつ分けて保存し、通し番号は最後の保存でだけ書くこと")
        func writesSequenceInLastSave() throws {
            try SyncBoxSaveOrder.apply(
                result, kinds: kinds, cache: cache,
                savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                saveCache: {
                    log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                },
                removePending: { log.saves.append(.removingPending(writeIds: $0)) })

            #expect(
                log.saves == [
                    .cache(changes: 100, afterSequence: nil),
                    .cache(changes: 100, afterSequence: nil),
                    .cache(changes: 50, afterSequence: 7),
                ])
            #expect(cache.appliedCount(of: .accountSettings) == 250)
        }
    }

    @Suite("変更が無く、通し番号だけを当てるとき")
    struct WritingOnlySequence {
        let log: SaveLog
        let cache: RecordCacheMock
        let kinds: RecordKindRegistry<RecordCacheMock>

        init() {
            log = SaveLog()
            cache = RecordCacheMock()
            kinds = RecordKindRegistry([RecordKindMock.ok()])
        }

        @Test("通し番号だけを1つの保存で書くこと")
        func writesSequenceAlone() throws {
            try SyncBoxSaveOrder.apply(
                SyncBoxResult(syncState: .fixture(afterSequence: 4)),
                kinds: kinds, cache: cache,
                savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                saveCache: {
                    log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                },
                removePending: { log.saves.append(.removingPending(writeIds: $0)) })

            #expect(log.saves == [.cache(changes: 0, afterSequence: 4)])
        }
    }

    @Suite("種類が変更を当てるのに失敗したとき")
    struct KindFailing {
        let log: SaveLog
        let cache: RecordCacheMock
        let kinds: RecordKindRegistry<RecordCacheMock>
        let result: SyncBoxResult

        init() {
            log = SaveLog()
            cache = RecordCacheMock()
            kinds = RecordKindRegistry([RecordKindMock.error(.init())])
            result = SyncBoxResult(
                kindChanges: [
                    KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")])
                ],
                syncState: .fixture(afterSequence: 9)
            )
        }

        @Test("通し番号を書かないこと")
        func keepsSequence() throws {
            #expect(throws: RecordKindMock.Failure()) {
                try SyncBoxSaveOrder.apply(
                    result, kinds: kinds, cache: cache,
                    savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                    saveCache: {
                        log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                    },
                    removePending: { log.saves.append(.removingPending(writeIds: $0)) })
            }

            #expect(log.saves.isEmpty)
        }
    }

    @Suite("登録簿に無い種類の変更を渡したとき")
    struct UnknownKind {
        let log: SaveLog
        let cache: RecordCacheMock
        let kinds: RecordKindRegistry<RecordCacheMock>
        let result: SyncBoxResult

        init() {
            log = SaveLog()
            cache = RecordCacheMock()
            kinds = RecordKindRegistry([RecordKindMock.ok()])
            result = SyncBoxResult(
                kindChanges: [
                    KindChanges(kind: .accountSettings, changes: [.unknown(kind: "note")]),
                    KindChanges(kind: .weightRecord, changes: []),
                ]
            )
        }

        @Test("知らない種類だと、どの変更も当てずに投げること")
        func throwsBeforeApplying() throws {
            #expect(throws: UnknownRecordKindError.notRegistered(.weightRecord)) {
                try SyncBoxSaveOrder.apply(
                    result, kinds: kinds, cache: cache,
                    savePending: { log.saves.append(.pending(enqueued: $0, healthSyncState: $1)) },
                    saveCache: {
                        log.saves.append(.cache(changes: $0, afterSequence: $1?.afterSequence))
                    },
                    removePending: { log.saves.append(.removingPending(writeIds: $0)) })
            }

            #expect(cache.appliedCount(of: .accountSettings) == 0)
            #expect(log.saves.isEmpty)
        }
    }

    /// 置き場の操作の閉包が呼ばれた順の記録。各テストの閉包が足す
    final class SaveLog {
        enum Save: Equatable {
            /// 送り待ちの置き場への保存。足した送り待ちと、書いたヘルスケアの同期の進み具合
            case pending(enqueued: [PendingEntry], healthSyncState: HealthSyncState?)
            /// キャッシュの置き場への保存。当てた変更の数と、この保存で書いた通し番号
            case cache(changes: Int, afterSequence: Int?)
            /// 結果を受け取った送り待ちを消す保存
            case removingPending(writeIds: Set<UUID>)
        }

        var saves: [Save] = []
    }
}
