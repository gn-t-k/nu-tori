import Foundation
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("週の見直しの同期")
    struct WeeklyReviewSync {
        static let reviewedId = "00000000-0000-4000-8000-0000000000b1"
        static let deferredId = "00000000-0000-4000-8000-0000000000b2"
        static let goalId = "00000000-0000-4000-8000-0000000000c1"
        static let guideId = "00000000-0000-4000-8000-0000000000d1"
        static let estimateId = "00000000-0000-4000-8000-0000000000e1"

        @Suite("週の見直しの変更を取りに行ったとき")
        struct PullingChanges {
            let client: NuToriAPIClient

            init() {
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json: """
                            {"changes":[
                              {"sequence":1,"kind":"weekly_review","recordId":"\(WeeklyReviewSync.reviewedId)",
                               "record":{"id":"\(WeeklyReviewSync.reviewedId)","effectiveOn":"2026-10-19",
                                 "reviewedAt":1792368000123,"timeZone":"Asia/Tokyo",
                                 "review":{"expenditureEstimateId":"\(WeeklyReviewSync.estimateId)",
                                   "dailyGuideId":"\(WeeklyReviewSync.guideId)","mainReason":"balance_change"}}},
                              {"sequence":2,"kind":"weekly_review","recordId":"\(WeeklyReviewSync.deferredId)",
                               "record":{"id":"\(WeeklyReviewSync.deferredId)","effectiveOn":"2026-10-26",
                                 "reviewedAt":1792972800000,"timeZone":"America/Los_Angeles",
                                 "deferral":{"reason":"few_meal_records","goalId":"\(WeeklyReviewSync.goalId)"}}},
                              {"sequence":3,"kind":"weekly_review","recordId":"\(WeeklyReviewSync.deferredId)",
                               "record":{"id":"\(WeeklyReviewSync.deferredId)","effectiveOn":"2026-10-26",
                                 "reviewedAt":1792972800000,"timeZone":"Asia/Tokyo",
                                 "deferral":{"reason":"reason_added_later","goalId":"\(WeeklyReviewSync.goalId)"}}},
                              {"sequence":4,"kind":"weekly_review","recordId":"\(WeeklyReviewSync.deferredId)",
                               "record":{"id":"\(WeeklyReviewSync.deferredId)","effectiveOn":"2026-10-26",
                                 "reviewedAt":1792972800000,"timeZone":"Asia/Tokyo"}}
                            ],"hasMore":false,"nextAfterSequence":4,"startedOn":"2026-09-29"}
                            """
                    ),
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("見直せた週と見送った週を解き、知らない見送りの理由と、見直しも見送りも無い週は読み飛ばせる形で返すこと")
            func returnsChanges() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: .fixture())

                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [
                                    .weeklyReview(
                                        SyncedWeeklyReview(
                                            id: try #require(
                                                UUID(uuidString: WeeklyReviewSync.reviewedId)),
                                            effectiveOn: "2026-10-19",
                                            reviewedAt: Date(
                                                timeIntervalSince1970: 1_792_368_000.123),
                                            timeZone: try #require(
                                                TimeZone(identifier: "Asia/Tokyo")),
                                            outcome: .reviewed(
                                                expenditureEstimateId: try #require(
                                                    UUID(uuidString: WeeklyReviewSync.estimateId)),
                                                dailyGuideId: try #require(
                                                    UUID(uuidString: WeeklyReviewSync.guideId)),
                                                mainReason: .balanceChange))),
                                    .weeklyReview(
                                        SyncedWeeklyReview(
                                            id: try #require(
                                                UUID(uuidString: WeeklyReviewSync.deferredId)),
                                            effectiveOn: "2026-10-26",
                                            reviewedAt: Date(timeIntervalSince1970: 1_792_972_800),
                                            timeZone: try #require(
                                                TimeZone(identifier: "America/Los_Angeles")),
                                            outcome: .deferred(
                                                reason: .fewMealRecords,
                                                goalId: try #require(
                                                    UUID(uuidString: WeeklyReviewSync.goalId))))),
                                    .unknown(kind: "weekly_review"),
                                    .unknown(kind: "weekly_review"),
                                ],
                                hasMore: false,
                                nextAfterSequence: 4,
                                startedOn: "2026-09-29"
                            )))
            }
        }
    }
}
