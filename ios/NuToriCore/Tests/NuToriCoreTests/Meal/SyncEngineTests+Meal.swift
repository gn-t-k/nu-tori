import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("食事と推定の状態の同期")
    struct MealKind {
        @Suite("食事を記録したとき")
        struct Recording {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let photoId: UUID

            init() throws {
                photoId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c1"))
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("送り待ちに食事の種類の名前で入れてから、キャッシュに食事を置くこと")
            func enqueuesThenCaches() async throws {
                let meal = try await engine.recordLunch(photoId: photoId)

                #expect(store.entries.map(\.kind) == [.meal])
                #expect(
                    store.saves == [
                        .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                    ])
                #expect(store.cache.meals[meal.id] == meal)
            }

            @Test("送ると、食事の時刻・時差・送った時刻・タイムゾーン・入口・写真を、作る書き込みで送ること")
            func sendsCreateMeal() async throws {
                let meal = try await engine.recordLunch(photoId: photoId)

                _ = try await engine.sync()

                let writes = try #require(transport.pushBodies.first).writes
                #expect(
                    writes.map(\.type) == ["create_meal"])
                guard case .createMeal(_, let sent) = try #require(writes.first) else {
                    Issue.record("作る書き込みでない: \(writes)")
                    return
                }
                #expect(
                    sent
                        == SentWritesBody.Meal(
                            id: meal.id.uuidString,
                            eatenAt: 1_790_046_600_000,
                            eatenAtUtcOffsetSeconds: 32_400,
                            sentAt: 1_790_046_660_000,
                            sentTimeZone: "Asia/Tokyo",
                            entryMethod: "captured",
                            photos: [.init(id: photoId.uuidString)]
                        ))
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("つながらないときに食事を消したとき")
        struct DeletingOffline {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let meal: Meal

            init() async throws {
                store = try .ok()
                engine = .fixture(
                    store: store, transport: .error(URLError(.notConnectedToInternet)))
                meal = try await engine.recordLunch(photoId: UUID())
                try await store.apply(
                    SyncBoxResult(kindChanges: [
                        KindChanges(
                            kind: .mealEstimationStatus,
                            changes: [
                                .mealEstimationStatus(
                                    SyncedMealEstimationStatus(
                                        mealId: meal.id, status: .awaitingPhotos))
                            ])
                    ]))
            }

            @Test("その場で食事と推定の状態をキャッシュから消すこと")
            func removesFromCacheAtOnce() async throws {
                try await engine.deleteMeal(id: meal.id)

                #expect(store.cache.meals[meal.id] == nil)
                #expect(store.cache.estimationStatuses[meal.id] == nil)
            }

            @Test("消す書き込みを送り待ちに残すこと")
            func keepsDeleteWritePending() async throws {
                try await engine.deleteMeal(id: meal.id)
                _ = try await engine.sync()

                #expect(store.entries.map(\.kind) == [.meal, .meal])
            }
        }

        @Suite("消した食事を送るとき")
        struct SendingDeletion {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let meal: Meal

            init() async throws {
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
                meal = try await engine.recordLunch(photoId: UUID())
                try await engine.deleteMeal(id: meal.id)
            }

            @Test("作る書き込みのあとに、食事の ID を添えた消す書き込みを送ること")
            func sendsDeleteAfterCreate() async throws {
                _ = try await engine.sync()

                let writes = try #require(transport.pushBodies.first).writes
                #expect(writes.map(\.type) == ["create_meal", "delete_meal"])
                #expect(
                    writes.last
                        == .deleteMeal(id: try #require(writes.last).id, mealId: meal.id.uuidString)
                )
            }
        }

        @Suite("サーバーが作る書き込みを受け付けず、サーバーに食事が無いとき")
        struct RejectedWithoutValue {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let meal: Meal

            init() async throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(rejectedWriteIndexes: [0], currents: [0: .absent]))
                meal = try await engine.recordLunch(photoId: UUID())
            }

            @Test("食事をキャッシュから外し、記録できなかった食事として返すこと")
            func removesMealAndReturnsLine() async throws {
                let result = try await engine.sync()

                #expect(store.cache.meals[meal.id] == nil)
                #expect(result.rejectedWrites.map(\.record) == [.meal(meal)])
            }
        }

        @Suite("サーバーが作る書き込みを受け付けず、食事が消されていたとき")
        struct RejectedForDeletedMeal {
            let engine: SyncEngine

            init() throws {
                let meal = Meal(
                    id: try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")),
                    draft: try .lunch(photoId: UUID()))
                engine = .fixture(
                    store: try .ok(pendingEntries: [
                        try PendingMealWrite(
                            writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                            write: .create(meal)
                        ).entry()
                    ]),
                    transport: .sync(
                        rejectedWriteIndexes: [0], currents: [0: .deletedMeal(mealId: meal.id)]))
            }

            @Test("消えた食事の行は出さないこと")
            func returnsNoLine() async throws {
                let result = try await engine.sync()

                #expect(result.rejectedWrites.isEmpty)
            }
        }

        @Suite("食事と推定の状態の変更を取りに行ったとき")
        struct Pulling {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let keptId: UUID
            let deletedId: UUID

            init() throws {
                keptId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1"))
                deletedId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f2"))
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"meal_estimation_status","recordId":"\(keptId.uuidString)",
                           "record":{"mealId":"\(keptId.uuidString)","status":"estimating"}},
                          \(Self.mealChange(sequence: 2, id: keptId)),
                          \(Self.mealChange(sequence: 3, id: deletedId)),
                          {"sequence":4,"kind":"meal_estimation_status","recordId":"\(deletedId.uuidString)",
                           "record":{"mealId":"\(deletedId.uuidString)","status":"failed"}},
                          {"sequence":5,"kind":"meal_estimation_status_deletion","recordId":"\(deletedId.uuidString)","record":{}},
                          {"sequence":6,"kind":"meal_deletion","recordId":"\(deletedId.uuidString)","record":{}}
                        ],"hasMore":false,"nextAfterSequence":6,"startedOn":null}
                        """
                    ]))
            }

            static func mealChange(sequence: Int, id: UUID) -> String {
                """
                {"sequence":\(sequence),"kind":"meal","recordId":"\(id.uuidString)",
                 "record":{"id":"\(id.uuidString)","eatenAt":1790046600000,"eatenAtUtcOffsetSeconds":32400,
                   "sentAt":1790046660000,"sentTimeZone":"Asia/Tokyo","entryMethod":"picked",
                   "photos":[{"id":"00000000-0000-4000-8000-0000000000c1"}]}}
                """
            }

            @Test("食事より先に届いた推定の状態も、食事と一緒にキャッシュに当てること")
            func appliesMealAndStatus() async throws {
                _ = try await engine.sync()

                #expect(store.cache.meals[keptId]?.entry == .picked)
                #expect(store.cache.estimationStatuses[keptId] == .estimating)
            }

            @Test("削除の印の食事と推定の状態をキャッシュから消すこと")
            func removesDeleted() async throws {
                _ = try await engine.sync()

                #expect(store.cache.meals[deletedId] == nil)
                #expect(store.cache.estimationStatuses[deletedId] == nil)
            }
        }

        @Suite("推定の状態の種類の送り待ちがあるとき")
        struct PendingServerOnlyKind {
            let engine: SyncEngine

            init() throws {
                engine = .fixture(
                    store: try .ok(pendingEntries: [
                        PendingEntry(
                            writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                            kind: .mealEstimationStatus, content: Data())
                    ]),
                    transport: .sync())
            }

            @Test("サーバーだけが書く種類として、送らずに投げること")
            func throwsServerOnly() async throws {
                await #expect(throws: UnknownRecordKindError.serverOnly(.mealEstimationStatus)) {
                    _ = try await engine.sync()
                }
            }
        }

        @Suite("読める種類に食事・推定の状態・料理・材料が増えた版で、更新して最初に開いたとき")
        struct AfterUpdateAddingMealKinds {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                store = try .ok(
                    state: .fixture(
                        afterSequence: 120, hasCompletedInitialPull: true,
                        readableKinds: [.accountSettings, .weightRecord]))
                transport = .sync()
                engine = .fixture(
                    store: store, transport: transport,
                    readableKinds: RecordKindRegistry<RecordCacheMock>.ok().names)
            }

            @Test("通し番号を 0 に戻して全部取り直し、読める種類に食事・推定の状態・料理・材料を足すこと")
            func pullsEverythingAgain() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.first?["afterSequence"] == "0")
                #expect(
                    store.state?.readableKinds.isSuperset(of: [
                        .accountSettings, .dish, .ingredient, .meal, .mealEstimationStatus,
                        .weightRecord,
                    ]) == true)
            }
        }
    }
}

extension SyncEngine {
    /// 昼の食事を、元の写真を添えて記録する
    fileprivate func recordLunch(photoId: UUID) async throws -> Meal {
        try await recordMeal(.lunch(photoId: photoId), originals: [photoId: Data([0x01])])
    }
}

extension MealDraft {
    /// 2026-09-22 12:10（東京）に撮り、1分後に送った昼の食事
    fileprivate static func lunch(photoId: UUID) throws -> MealDraft {
        MealDraft.captured(
            photoId: photoId,
            takenAt: Date(timeIntervalSince1970: 1_790_046_600),
            sentAt: Date(timeIntervalSince1970: 1_790_046_660),
            deviceTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
    }
}
