import Foundation
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("食事と推定の状態の同期")
    struct MealSync {
        static let mealId = "00000000-0000-4000-8000-0000000000F1"

        @Suite("食事を作る書き込みと消す書き込みを送るとき")
        struct PushingMealWrites {
            let createWriteId: UUID
            let deleteWriteId: UUID
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let writes: [SyncWrite]

            init() throws {
                createWriteId = try #require(
                    UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
                deleteWriteId = try #require(
                    UUID(uuidString: "00000000-0000-4000-8000-0000000000a2"))
                writes = [
                    .createMeal(writeId: createWriteId, meal: try .fixture()),
                    .deleteMeal(
                        writeId: deleteWriteId,
                        mealId: try #require(UUID(uuidString: MealSync.mealId))),
                ]
                transport = .ok(
                    json: """
                        {"results":[
                          {"writeId":"\(createWriteId.uuidString)","result":"rejected","rejectionReason":"photo_already_used"},
                          {"writeId":"\(deleteWriteId.uuidString)","result":"applied"}
                        ]}
                        """
                )
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    appBuild: 1,
                    sessionToken: { "session-1" },
                    appBuildVerdict: { _ in }
                )
            }

            @Test("作る書き込みは食事の時刻・時差・送った時刻・タイムゾーン・入口・写真の並びを、消す書き込みは食事の ID を送ること")
            func sendsMealWrites() async throws {
                _ = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: .fixture())

                let sent = try #require(transport.requests.first)
                #expect(
                    try SentWritesBody(json: sent.body ?? "").writes == [
                        .createMeal(
                            id: createWriteId.uuidString,
                            .init(
                                id: MealSync.mealId,
                                eatenAt: 1_767_225_600_123,
                                eatenAtUtcOffsetSeconds: 32_400,
                                sentAt: 1_767_225_660_000,
                                sentTimeZone: "Asia/Tokyo",
                                entryMethod: "picked",
                                photos: [
                                    .init(id: "00000000-0000-4000-8000-0000000000C1"),
                                    .init(id: "00000000-0000-4000-8000-0000000000C2"),
                                ]
                            )
                        ),
                        .deleteMeal(id: deleteWriteId.uuidString, mealId: MealSync.mealId),
                    ])
            }

            @Test("食事で足した受け付けなかった理由を読むこと")
            func readsMealRejectionReason() async throws {
                let result = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: .fixture())

                guard case .pushed(let results) = result else {
                    Issue.record("結果が返っていない: \(result)")
                    return
                }
                #expect(results.map(\.outcome) == [.rejected(.photoAlreadyUsed), .applied])
            }
        }

        @Suite("食事と推定の状態の変更を取りに行ったとき")
        struct PullingMealChanges {
            let client: NuToriAPIClient

            init() {
                let id = MealSync.mealId
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json: """
                            {"changes":[
                              {"sequence":1,"kind":"meal","recordId":"\(id)",
                               "record":{"id":"\(id)","eatenAt":1767225600123,"eatenAtUtcOffsetSeconds":32400,
                                 "sentAt":1767225660000,"sentTimeZone":"Asia/Tokyo","entryMethod":"picked",
                                 "photos":[{"id":"00000000-0000-4000-8000-0000000000C1"},{"id":"00000000-0000-4000-8000-0000000000C2"}]}},
                              {"sequence":2,"kind":"meal_estimation_status","recordId":"\(id)",
                               "record":{"mealId":"\(id)","status":"deferred_to_next_day"}},
                              {"sequence":3,"kind":"meal_estimation_status","recordId":"\(id)",
                               "record":{"mealId":"\(id)","status":"archived"}},
                              {"sequence":4,"kind":"meal","recordId":"\(id)",
                               "record":{"id":"\(id)","eatenAt":1767225600123,"eatenAtUtcOffsetSeconds":32400,
                                 "sentAt":1767225660000,"sentTimeZone":"Asia/Tokyo","entryMethod":"drawn","photos":[]}},
                              {"sequence":5,"kind":"meal_deletion","recordId":"\(id)","record":{}},
                              {"sequence":6,"kind":"meal_estimation_status_deletion","recordId":"\(id)","record":{}}
                            ],"hasMore":false,"nextAfterSequence":6,"startedOn":"2026-09-29"}
                            """
                    ),
                    appBuild: 1,
                    sessionToken: { "session-1" },
                    appBuildVerdict: { _ in }
                )
            }

            @Test("食事・推定の状態・それぞれの削除の印を解き、知らない状態と入口は読み飛ばせる形で返すこと")
            func returnsMealChanges() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: .fixture())

                let mealId = try #require(UUID(uuidString: MealSync.mealId))
                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [
                                    .meal(try .fixture()),
                                    .mealEstimationStatus(
                                        SyncedMealEstimationStatus(
                                            mealId: mealId, status: .deferredToNextDay)),
                                    .unknown(kind: "meal_estimation_status"),
                                    .unknown(kind: "meal"),
                                    .mealDeletion(mealId: mealId),
                                    .mealEstimationStatusDeletion(mealId: mealId),
                                ],
                                hasMore: false,
                                nextAfterSequence: 6,
                                startedOn: "2026-09-29"
                            )))
            }
        }
    }
}

extension SyncedMeal {
    fileprivate static func fixture() throws -> SyncedMeal {
        SyncedMeal(
            id: try #require(UUID(uuidString: NuToriAPIClientTests.MealSync.mealId)),
            eatenAt: Date(timeIntervalSince1970: 1_767_225_600.123),
            eatenUtcOffsetSeconds: 32_400,
            sentAt: Date(timeIntervalSince1970: 1_767_225_660),
            sentTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            entryMethod: .picked,
            photoIds: [
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")),
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c2")),
            ]
        )
    }
}
