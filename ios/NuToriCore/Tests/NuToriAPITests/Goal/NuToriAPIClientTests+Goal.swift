import Foundation
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("目標・1日の目安・推定消費カロリー・目標を立てる知らせの同期")
    struct GoalSync {
        static let goalId = "00000000-0000-4000-8000-0000000000c1"
        static let nextGoalId = "00000000-0000-4000-8000-0000000000c2"
        static let guideId = "00000000-0000-4000-8000-0000000000d1"
        static let estimateId = "00000000-0000-4000-8000-0000000000e1"
        static let noticeId = "00000000-0000-5000-8000-0000000000f1"

        static func client(transport: ClientTransportMock) -> NuToriAPIClient {
            NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            )
        }

        @Suite("目標を立てる知らせを作る書き込みを送るとき")
        struct PushingGoalSetupNotice {
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let writes: [SyncWrite]

            init() throws {
                let writeId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
                writes = [
                    .createNotice(
                        writeId: writeId,
                        notice: NewNotice(
                            id: try #require(UUID(uuidString: GoalSync.noticeId)),
                            noticeType: .goalSetup,
                            issuedAt: Date(timeIntervalSince1970: 1_767_225_600),
                            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))))
                ]
                transport = .ok(
                    json: """
                        {"results":[{"writeId":"\(writeId.canonicalString)","result":"applied"}]}
                        """)
                client = GoalSync.client(transport: transport)
            }

            @Test("種類を goal_setup にし、対象の日付を付けずに送ること")
            func sendsWithoutTargetOn() async throws {
                _ = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: .fixture())

                let sent = try #require(transport.requests.first)
                #expect(
                    try PushSyncWritesPayload(sentBody: sent.body).writes == [
                        .createNotice(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a1",
                                _type: .createNotice,
                                notice: .init(
                                    id: GoalSync.noticeId,
                                    noticeType: "goal_setup",
                                    issuedAt: 1_767_225_600_000,
                                    timeZone: "Asia/Tokyo",
                                    targetOn: nil
                                ))
                        )
                    ])
                #expect(sent.body?.contains("targetOn") == false)
            }
        }

        @Suite("目標・1日の目安・推定消費カロリー・目標を立てる知らせの変更を取りに行ったとき")
        struct PullingChanges {
            let client: NuToriAPIClient

            init() {
                client = GoalSync.client(
                    transport: .ok(
                        json: """
                            {"changes":[
                              {"sequence":1,"kind":"daily_guide","recordId":"\(GoalSync.guideId)",
                               "record":{"id":"\(GoalSync.guideId)","goalId":"\(GoalSync.goalId)",
                                 "expenditureEstimateId":"\(GoalSync.estimateId)","effectiveOn":"2026-10-01",
                                 "energyKcal":1850,"proteinG":130,"fatG":50,"carbohydrateG":220,
                                 "limitHits":["minimum_energy","limit_added_later"]}},
                              {"sequence":2,"kind":"expenditure_estimate","recordId":"\(GoalSync.estimateId)",
                               "record":{"id":"\(GoalSync.estimateId)","effectiveOn":"2026-10-01",
                                 "expenditureKcal":2300,"estimatedAt":1790812800123,"initialSource":"formula"}},
                              {"sequence":3,"kind":"goal","recordId":"\(GoalSync.goalId)",
                               "record":{"id":"\(GoalSync.goalId)","startedOn":"2026-10-01",
                                 "startingWeightTrendKg":72.4,"targetWeightKg":68,"decidedAt":1790812800123,
                                 "timeZone":"Asia/Tokyo","direction":"lose",
                                 "weightChange":{"deadlineOn":"2026-12-24","pacePlan":"custom"},
                                 "achievement":{"achievedOn":"2026-12-10","judgedAt":1796860800123,
                                   "timeZone":"Asia/Tokyo"},
                                 "deadlineConfirmation":{"deadlineWeightTrendKg":68.4,
                                   "confirmedAt":1797033600000,"timeZone":"America/Los_Angeles"},
                                 "closure":{"endedOn":"2026-12-28","nextGoalId":"\(GoalSync.nextGoalId)",
                                   "endReason":"moved_to_maintenance"}}},
                              {"sequence":4,"kind":"goal","recordId":"\(GoalSync.nextGoalId)",
                               "record":{"id":"\(GoalSync.nextGoalId)","startedOn":"2026-10-20",
                                 "startingWeightTrendKg":70.1,"targetWeightKg":70.1,"decidedAt":1792454400000,
                                 "timeZone":"America/Los_Angeles","direction":"maintain"}},
                              {"sequence":5,"kind":"expenditure_estimate","recordId":"\(GoalSync.estimateId)",
                               "record":{"id":"\(GoalSync.estimateId)","effectiveOn":"2026-10-08",
                                 "expenditureKcal":2250,"estimatedAt":1791417600000}},
                              {"sequence":6,"kind":"notice","recordId":"\(GoalSync.noticeId)",
                               "record":{"id":"\(GoalSync.noticeId)","noticeType":"goal_setup",
                                 "issuedAt":1767225600123,"timeZone":"Asia/Tokyo"}},
                              {"sequence":7,"kind":"goal","recordId":"\(GoalSync.goalId)",
                               "record":{"id":"\(GoalSync.goalId)","startedOn":"2026-10-01",
                                 "startingWeightTrendKg":72.4,"targetWeightKg":68,"decidedAt":1790812800123,
                                 "timeZone":"Asia/Tokyo","direction":"lose",
                                 "weightChange":{"deadlineOn":"2026-12-24","pacePlan":"plan_added_later"}}},
                              {"sequence":8,"kind":"goal","recordId":"\(GoalSync.goalId)",
                               "record":{"id":"\(GoalSync.goalId)","startedOn":"2026-10-01",
                                 "startingWeightTrendKg":72.4,"targetWeightKg":68,"decidedAt":1790812800123,
                                 "timeZone":"Asia/Tokyo","direction":"gain"}},
                              {"sequence":9,"kind":"notice","recordId":"\(GoalSync.noticeId)",
                               "record":{"id":"\(GoalSync.noticeId)","noticeType":"missed_weight_record",
                                 "issuedAt":1767225600123,"timeZone":"Asia/Tokyo"}},
                              {"sequence":10,"kind":"goal","recordId":"\(GoalSync.goalId)",
                               "record":{"id":"\(GoalSync.goalId)","startedOn":"2026-10-01",
                                 "startingWeightTrendKg":72.4,"targetWeightKg":68,"decidedAt":1790812800123,
                                 "timeZone":"Asia/Tokyo","direction":"lose",
                                 "weightChange":{"deadlineOn":"2026-12-24","pacePlan":"custom"},
                                 "closure":{"endedOn":"2026-10-20","nextGoalId":"\(GoalSync.nextGoalId)",
                                   "endReason":"reason_added_later"}}}
                            ],"hasMore":false,"nextAfterSequence":10,"startedOn":"2026-09-29"}
                            """
                    ))
            }

            @Test(
                "3つの種類（目標の達成・期限の日の確定・終わり方を含む）と対象の日付の無い目標を立てる知らせを解き、知らない速さの案・期限の無い増量・対象の日付の無い記録忘れの知らせ・知らない終わり方は読み飛ばせる形で返すこと"
            )
            func returnsChanges() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: .fixture())

                let goalId = try #require(UUID(uuidString: GoalSync.goalId))
                let nextGoalId = try #require(UUID(uuidString: GoalSync.nextGoalId))
                let guideId = try #require(UUID(uuidString: GoalSync.guideId))
                let estimateId = try #require(UUID(uuidString: GoalSync.estimateId))
                let noticeId = try #require(UUID(uuidString: GoalSync.noticeId))
                let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
                let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [
                                    .dailyGuide(
                                        SyncedDailyGuide(
                                            id: guideId, goalId: goalId,
                                            expenditureEstimateId: estimateId,
                                            effectiveOn: "2026-10-01", energyKilocalories: 1850,
                                            proteinGrams: 130, fatGrams: 50,
                                            carbohydrateGrams: 220, limitHits: [.minimumEnergy])),
                                    .expenditureEstimate(
                                        SyncedExpenditureEstimate(
                                            id: estimateId, effectiveOn: "2026-10-01",
                                            expenditureKilocalories: 2300,
                                            estimatedAt: Date(
                                                timeIntervalSince1970: 1_790_812_800.123),
                                            initialSource: .formula)),
                                    .goal(
                                        SyncedGoal(
                                            id: goalId, startedOn: "2026-10-01",
                                            startingWeightTrendKilograms: 72.4,
                                            targetWeightKilograms: 68,
                                            decidedAt: Date(
                                                timeIntervalSince1970: 1_790_812_800.123),
                                            timeZone: tokyo,
                                            direction: .lose(
                                                .init(deadlineOn: "2026-12-24", pacePlan: .custom)),
                                            achievement: .init(
                                                achievedOn: "2026-12-10",
                                                judgedAt: Date(
                                                    timeIntervalSince1970: 1_796_860_800.123),
                                                timeZone: tokyo),
                                            deadlineConfirmation: .init(
                                                deadlineWeightTrendKilograms: 68.4,
                                                confirmedAt: Date(
                                                    timeIntervalSince1970: 1_797_033_600),
                                                timeZone: losAngeles),
                                            closure: .init(
                                                endedOn: "2026-12-28", nextGoalId: nextGoalId,
                                                endReason: .movedToMaintenance))),
                                    .goal(
                                        SyncedGoal(
                                            id: nextGoalId, startedOn: "2026-10-20",
                                            startingWeightTrendKilograms: 70.1,
                                            targetWeightKilograms: 70.1,
                                            decidedAt: Date(timeIntervalSince1970: 1_792_454_400),
                                            timeZone: losAngeles, direction: .maintain,
                                            achievement: nil, deadlineConfirmation: nil,
                                            closure: nil)),
                                    .expenditureEstimate(
                                        SyncedExpenditureEstimate(
                                            id: estimateId, effectiveOn: "2026-10-08",
                                            expenditureKilocalories: 2250,
                                            estimatedAt: Date(timeIntervalSince1970: 1_791_417_600),
                                            initialSource: nil)),
                                    .notice(
                                        SyncedNotice(
                                            id: noticeId, noticeType: .goalSetup,
                                            issuedAt: Date(
                                                timeIntervalSince1970: 1_767_225_600.123),
                                            timeZone: tokyo, response: nil)),
                                    .unknown(kind: "goal"),
                                    .unknown(kind: "goal"),
                                    .unknown(kind: "notice"),
                                    .unknown(kind: "goal"),
                                ],
                                hasMore: false,
                                nextAfterSequence: 10,
                                startedOn: "2026-09-29"
                            )))
            }
        }
    }
}
