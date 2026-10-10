import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("送った文章と状態と返事の同期")
    struct SentTextKind {
        @Suite("文章を送ったとき")
        struct Sending {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("前後の空白を除いた本文と、送った時刻とタイムゾーンで、送った文章を作ること")
            func createsSentText() async throws {
                let sentText = try #require(try await engine.sendText("  朝はトーストと牛乳\n"))

                #expect(sentText.body == "朝はトーストと牛乳")
                #expect(sentText.sentAt == SyncEngine.fixtureNow)
                #expect(sentText.timeZone == TimeZone(identifier: "Asia/Tokyo"))
            }

            @Test("送り待ちに送った文章の種類の名前で入れてから、キャッシュに送った文章を置くこと")
            func enqueuesThenCaches() async throws {
                let sentText = try #require(try await engine.sendText("朝はトーストと牛乳"))

                #expect(store.entries.map(\.kind) == [.sentText])
                #expect(
                    store.saves == [
                        .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                    ])
                #expect(store.cache.sentTexts[sentText.id] == sentText)
            }

            @Test("送ると、ID・本文・送った時刻・タイムゾーンを、作る書き込みで送ること")
            func sendsCreateSentText() async throws {
                let sentText = try #require(try await engine.sendText("朝はトーストと牛乳"))

                _ = try await engine.sync()

                let write = try #require(try transport.pushBodies.first?.writes.first)
                #expect(
                    write
                        == .createSentText(
                            writeId: write.writeId,
                            sentText: SyncedSentText(
                                id: sentText.id, body: "朝はトーストと牛乳",
                                sentAt: SyncEngine.fixtureNow,
                                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))))
                #expect(store.entries.isEmpty)
            }

            @Test("届くまでは応答を待つ文章とせず、届いたら応答を待つ文章とすること")
            func awaitsResponseAfterDelivered() async throws {
                let sentText = try #require(try await engine.sendText("次は何を食べたらいい？"))
                #expect(try await engine.sentTextsAwaitingResponse().isEmpty)

                _ = try await engine.sync()

                #expect(try await engine.sentTextsAwaitingResponse() == [sentText.id])
            }
        }

        @Suite("空白だけの文章を送ろうとしたとき")
        struct SendingBlank {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(store: store, transport: .sync())
            }

            @Test("送った文章を作らず、送り待ちにも入れないこと")
            func sendsNothing() async throws {
                let sentText = try await engine.sendText(" \n　")

                #expect(sentText == nil)
                #expect(store.entries.isEmpty)
                #expect(store.cache.sentTexts.isEmpty)
            }
        }

        @Suite("文章の長さを、前後の空白を除いたコードポイントで数えるとき")
        struct SendingLongText {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            /// 見た目の1字で 100 字、コードポイントで 500 字（家族の絵文字は5つのコードポイント）
            let fiveHundredCodePoints: String

            init() throws {
                store = try .ok()
                engine = .fixture(store: store, transport: .sync())
                fiveHundredCodePoints = String(repeating: "👨‍👩‍👧", count: 100)
            }

            @Test("前後に空白のついた 500 字の文章を送ること")
            func sendsFiveHundred() async throws {
                let sentText = try await engine.sendText(" \(fiveHundredCodePoints)\n")

                #expect(sentText?.body == fiveHundredCodePoints)
            }

            @Test("501 字の文章を送らないこと")
            func refusesFiveHundredOne() async throws {
                let sentText = try await engine.sendText("\(fiveHundredCodePoints)a")

                #expect(sentText == nil)
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("サーバーが作る書き込みを受け付けず、サーバーに文章が無いとき")
        struct RejectedWithoutValue {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(rejectedWriteIndexes: [0], currents: [0: .absent]))
            }

            @Test("送った文章をキャッシュから外し、送れなかった文章の行を返すこと")
            func removesSentTextAndReturnsLine() async throws {
                let sentText = try #require(try await engine.sendText("朝はトーストと牛乳"))

                let result = try await engine.sync()

                #expect(store.cache.sentTexts[sentText.id] == nil)
                #expect(
                    result.rejectedWrites.map(\.record)
                        == [.sentText(RejectedSentTextLine(sentText: sentText, subject: .send))])
            }
        }

        @Suite("食事と読み分けた文章を会話として送り直したとき")
        struct ResendingAsConversation {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let sentText: SentText
            let writtenMealIds: [UUID]
            let otherMealId: UUID
            let dishId: UUID
            let ingredientId: UUID

            init() async throws {
                sentText = try .breakfastAndLunch()
                writtenMealIds = [UUID(), UUID()]
                otherMealId = UUID()
                dishId = UUID()
                ingredientId = UUID()
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
                let meals =
                    try writtenMealIds.map {
                        try SyncedMeal.written(id: $0, sentTextId: sentText.id)
                    } + [try SyncedMeal.written(id: otherMealId, sentTextId: UUID())]
                try await store.apply(
                    SyncBoxResult(kindChanges: [
                        KindChanges(kind: .meal, changes: meals.map { .meal($0) }),
                        KindChanges(kind: .sentText, changes: [.sentText(.init(sentText))]),
                        KindChanges(
                            kind: .mealEstimationStatus,
                            changes: writtenMealIds.map {
                                .mealEstimationStatus(.init(mealId: $0, status: .estimated))
                            }),
                        KindChanges(
                            kind: .dish,
                            changes: [
                                .dish(
                                    SyncedDish(
                                        id: dishId, mealId: writtenMealIds[1], name: "うどん",
                                        quantity: nil, positionInMeal: 0, version: 1))
                            ]),
                        KindChanges(
                            kind: .dishEstimationStatus,
                            changes: [
                                .dishEstimationStatus(.init(dishId: dishId, status: .estimated))
                            ]),
                        KindChanges(
                            kind: .ingredient,
                            changes: [.ingredient(.noodles(id: ingredientId, dishId: dishId))]),
                    ]))
            }

            @Test("その場で、その文章から作った食事と、その料理・材料・推定の状態をキャッシュから消すこと")
            func removesWrittenMealsAtOnce() async throws {
                try await engine.resendAsConversation(sentTextId: sentText.id)

                #expect(Set(store.cache.meals.keys) == [otherMealId])
                #expect(store.cache.estimationStatuses.isEmpty)
                #expect(store.cache.dishes.isEmpty)
                #expect(store.cache.dishEstimationStatuses.isEmpty)
                #expect(store.cache.ingredients.isEmpty)
            }

            @Test("会話として送り直す書き込み1つを、送り待ちに入れること")
            func enqueuesOneWrite() async throws {
                try await engine.resendAsConversation(sentTextId: sentText.id)

                #expect(
                    try store.entries.map { try PendingSentTextWrite(entry: $0).write }
                        == [.resendAsConversation(sentTextId: sentText.id)])
            }

            @Test("送ると、その文章を、会話として送り直す書き込みで送ること")
            func sendsResendAsConversation() async throws {
                try await engine.resendAsConversation(sentTextId: sentText.id)

                _ = try await engine.sync()

                let write = try #require(try transport.pushBodies.first?.writes.first)
                #expect(
                    write
                        == .resendSentTextAsConversation(
                            writeId: write.writeId, sentTextId: sentText.id))
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("返事を作れなかった文章を送り直したとき")
        struct Resending {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let sentText: SentText

            init() async throws {
                sentText = try .breakfastAndLunch()
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
                try await store.apply(
                    SyncBoxResult(kindChanges: [
                        KindChanges(
                            kind: .sentText, changes: [.sentText(.init(sentText))])
                    ]))
            }

            @Test("送り直す書き込み1つを送り待ちに入れ、キャッシュは変えないこと")
            func enqueuesOneWrite() async throws {
                try await engine.resend(sentTextId: sentText.id)

                #expect(
                    try store.entries.map { try PendingSentTextWrite(entry: $0).write }
                        == [.resend(sentTextId: sentText.id)])
                #expect(store.saves.last == .pending(added: 1, removed: 0))
            }

            @Test("送ると、その文章を、送り直す書き込みで送ること")
            func sendsResend() async throws {
                try await engine.resend(sentTextId: sentText.id)

                _ = try await engine.sync()

                let write = try #require(try transport.pushBodies.first?.writes.first)
                #expect(write == .resendSentText(writeId: write.writeId, sentTextId: sentText.id))
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("返事と送った文章の状態が、送った文章より先に届いたとき")
        struct ReceivingBeforeSentText {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let sentTextId: UUID
            let utteranceId: UUID
            let mealIds: [UUID]

            init() throws {
                sentTextId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
                utteranceId = try #require(
                    UUID(uuidString: "00000000-0000-4000-8000-0000000000a2"))
                mealIds = [
                    try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f2")),
                    try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")),
                ]
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"sent_text_status","recordId":"\(sentTextId.uuidString)",
                           "record":{"sentTextId":"\(sentTextId.uuidString)","classification":"conversation",
                             "replyStatus":"replied"}},
                          {"sequence":2,"kind":"ai_utterance","recordId":"\(utteranceId.uuidString)",
                           "record":{"id":"\(utteranceId.uuidString)","body":"いいですね",
                             "sentTextId":"\(sentTextId.uuidString)",
                             "mealIds":["\(mealIds[0].uuidString)","\(mealIds[1].uuidString)"]}}
                        ],"hasMore":false,"nextAfterSequence":2,"startedOn":null}
                        """
                    ]))
            }

            @Test("送った文章の無い状態と返事も、キャッシュに置くこと")
            func keepsStatusAndUtterance() async throws {
                _ = try await engine.sync()

                #expect(store.cache.sentTexts.isEmpty)
                #expect(
                    store.cache.sentTextStatuses[sentTextId]
                        == .init(classification: .conversation, reply: .replied)
                )
                #expect(
                    store.cache.aiUtterances[utteranceId]
                        == AiUtterance(
                            id: utteranceId, body: "いいですね", sentTextId: sentTextId,
                            mealIds: mealIds))
            }
        }

        @Suite("作れなかった・回数切れ・知らない応答の状態が届いたとき")
        struct ReceivingReplyStatuses {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let failedId: UUID
            let haltedId: UUID
            let unknownId: UUID

            init() throws {
                failedId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
                haltedId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b2"))
                unknownId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b3"))
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"sent_text_status","recordId":"\(failedId.uuidString)",
                           "record":{"sentTextId":"\(failedId.uuidString)","classification":"conversation",
                             "replyStatus":"failed","replyFailureReason":"bad_request"}},
                          {"sequence":2,"kind":"sent_text_status","recordId":"\(haltedId.uuidString)",
                           "record":{"sentTextId":"\(haltedId.uuidString)","classification":"conversation",
                             "replyStatus":"halted"}},
                          {"sequence":3,"kind":"sent_text_status","recordId":"\(unknownId.uuidString)",
                           "record":{"sentTextId":"\(unknownId.uuidString)","classification":"conversation",
                             "replyStatus":"thinking"}}
                        ],"hasMore":false,"nextAfterSequence":3,"startedOn":null}
                        """
                    ]))
            }

            @Test("作れなかった理由と回数切れを読み、知らない応答の状態は読み飛ばすこと")
            func readsReplyStatuses() async throws {
                _ = try await engine.sync()

                #expect(
                    store.cache.sentTextStatuses == [
                        failedId: .init(classification: .conversation, reply: .failed(.badRequest)),
                        haltedId: .init(classification: .conversation, reply: .halted),
                    ])
            }
        }

        @Suite("文章の食事が届いたとき")
        struct ReceivingWrittenMeal {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let mealId: UUID
            let sentTextId: UUID

            init() throws {
                mealId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1"))
                sentTextId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[\(writtenMealChange(mealId: mealId, sentTextId: sentTextId))],
                         "hasMore":false,"nextAfterSequence":1,"startedOn":null}
                        """
                    ]))
            }

            @Test("入口を文章にし、送った文章の ID を持つ食事としてキャッシュに置くこと")
            func readsWrittenEntry() async throws {
                _ = try await engine.sync()

                #expect(store.cache.meals[mealId]?.entry == .written(sentTextId: sentTextId))
            }
        }

        @Suite("送った文章の種類が増えた版で、更新して最初に開いたとき")
        struct AfterUpdateAddingSentTextKinds {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let mealId: UUID

            init() throws {
                mealId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1"))
                store = try .ok(
                    state: .fixture(
                        afterSequence: 120, hasCompletedInitialPull: true,
                        readableKinds: [
                            .accountSettings, .dish, .dishEstimationStatus, .ingredient, .meal,
                            .mealEstimationStatus, .notice, .usualWeighingTime, .weightRecord,
                            .weightTrend,
                        ]))
                // 前の版が読み飛ばした文章の食事は、通し番号 7 で届いていた
                transport = .sync(pullPages: [
                    """
                    {"changes":[\(writtenMealChange(mealId: mealId, sentTextId: UUID()))],
                     "hasMore":false,"nextAfterSequence":120,"startedOn":null}
                    """
                ])
                engine = .fixture(
                    store: store, transport: transport,
                    readableKinds: RecordKindRegistry<RecordCacheMock>.ok().names)
            }

            @Test("通し番号を 0 に戻して全部取り直し、読める種類に送った文章・状態・返事を足すこと")
            func pullsEverythingAgain() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.first?["afterSequence"] == "0")
                #expect(
                    store.state?.readableKinds.isSuperset(of: [
                        .aiUtterance, .sentText, .sentTextStatus,
                    ]) == true)
            }

            @Test("前の版が読み飛ばした文章の食事も、キャッシュに入ること")
            func receivesSkippedWrittenMeal() async throws {
                _ = try await engine.sync()

                #expect(store.cache.meals[mealId] != nil)
            }
        }
    }
}

/// 取りに行く変更の、文章の食事の JSON
private func writtenMealChange(mealId: UUID, sentTextId: UUID) -> String {
    """
    {"sequence":7,"kind":"meal","recordId":"\(mealId.uuidString)",
     "record":{"id":"\(mealId.uuidString)","eatenAt":1790028000000,"eatenAtUtcOffsetSeconds":32400,
       "sentAt":1790046660000,"sentTimeZone":"Asia/Tokyo","entryMethod":"written",
       "sentTextId":"\(sentTextId.uuidString)","photos":[]}}
    """
}

extension SentText {
    /// 2026-09-22 12:11（東京）に送った、朝と昼の食事の文章
    fileprivate static func breakfastAndLunch() throws -> SentText {
        SentText(
            id: UUID(), body: "朝はパン、昼はうどん",
            sentAt: Date(timeIntervalSince1970: 1_790_046_660),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
    }
}

extension SyncedSentText {
    fileprivate init(_ sentText: SentText) {
        self.init(
            id: sentText.id, body: sentText.body, sentAt: sentText.sentAt,
            timeZone: sentText.timeZone)
    }
}

extension SyncedMeal {
    /// 2026-09-22 12:11（東京）に送った文章から作った食事
    fileprivate static func written(id: UUID, sentTextId: UUID) throws -> SyncedMeal {
        SyncedMeal(
            id: id,
            eatenAt: Date(timeIntervalSince1970: 1_790_046_660),
            eatenUtcOffsetSeconds: 32_400,
            sentAt: Date(timeIntervalSince1970: 1_790_046_660),
            sentTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            entryMethod: .written(sentTextId: sentTextId),
            photoIds: []
        )
    }
}

extension SyncedIngredient {
    fileprivate static func noodles(id: UUID, dishId: UUID) -> SyncedIngredient {
        SyncedIngredient(
            id: id, dishId: dishId, name: "ゆでうどん", quantity: 1, quantitySource: .estimated,
            unit: "玉", edibleGramsPerUnit: 200, positionInDish: 0, nutrientSource: .estimated,
            nutrients: ["energy_kcal": 95])
    }
}
