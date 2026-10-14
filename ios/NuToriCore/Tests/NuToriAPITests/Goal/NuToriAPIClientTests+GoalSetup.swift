import Foundation
import HTTPTypes
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("目標の設定の要求")
    struct GoalSetup {
        static let goalId = "00000000-0000-4000-8000-0000000000c1"
        static let guideId = "00000000-0000-4000-8000-0000000000d1"
        static let estimateId = "00000000-0000-4000-8000-0000000000e1"

        static func client(transport: ClientTransportMock) -> NuToriAPIClient {
            NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            )
        }

        static let firstGoalInputs = GoalSetupInputs(
            timeZone: TimeZone(identifier: "Asia/Tokyo")!,
            preUseEnergyIntakes: ["2025-12-05": 2100, "2025-12-04": 1900.5],
            body: GoalSetupBody(
                sex: .female, heightCentimeters: 160.5, ageYears: 35,
                activity: .steps(["2025-12-05": 8000, "2025-12-04": 4000])))

        static let weightChangeProposalsJSON = """
            {"startedOn":"2026-01-01","direction":"lose","expenditureKcal":2250,
            "expenditureSource":"back_calculated","startingWeightTrendKg":70.04,
            "lastWeightRecordedOn":"2025-12-31","deadlineOn":"2026-03-31",
            "proposals":[
            {"pace":"gentle","status":"offered","targetWeightKg":67.7,
            "dailyGuide":{"energyKcal":2050,"proteinG":110,"fatG":55,"carbohydrateG":280},
            "difficulty":"gentle","dailyGuideDifferenceKcal":-200},
            {"pace":"standard","status":"offered","targetWeightKg":65.5,
            "dailyGuide":{"energyKcal":1850,"proteinG":105,"fatG":50,"carbohydrateG":245},
            "difficulty":"standard","dailyGuideDifferenceKcal":-400},
            {"pace":"hard","status":"unavailable","unavailableReason":"daily_guide_below_minimum"}],
            "acceptedTargetWeightRange":{"minimumKg":64.1,"maximumKg":69.9,
            "fastestEndReason":"daily_guide_below_minimum"}}
            """

        @Suite("目標の下見")
        struct Preview {
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
                transport = .ok(json: #"{"canBackCalculate":false}"#)
                client = GoalSetup.client(transport: transport)
            }

            @Test("向き・タイムゾーン・日の順の摂取エネルギー・身体データを POST /v1/goal-setup/preview に送ること")
            func sendsInputs() async throws {
                _ = try await client.previewGoalSetup(
                    direction: .lose, inputs: GoalSetup.firstGoalInputs)

                let sent = try #require(transport.requests.first)
                #expect(sent.request.method == .post)
                #expect(sent.request.path == "/v1/goal-setup/preview")
                let body = try JSONDecoder().decode(
                    Operations.PreviewGoalSetup.Input.Body.JsonPayload.self,
                    from: Data((sent.body ?? "").utf8))
                #expect(body.direction == .lose)
                #expect(body.timeZone == "Asia/Tokyo")
                #expect(
                    body.preUseEnergyIntakes == [
                        .init(calendarDay: "2025-12-04", kcal: 1900.5),
                        .init(calendarDay: "2025-12-05", kcal: 2100),
                    ])
                #expect(
                    body.bodyData
                        == .init(
                            sex: .female, heightCentimeters: 160.5, ageYears: 35,
                            activity: .steps(
                                .init(
                                    _type: .steps,
                                    dailySteps: [
                                        .init(calendarDay: "2025-12-04", steps: 4000),
                                        .init(calendarDay: "2025-12-05", steps: 8000),
                                    ]))))
            }

            @Test("付いていない答えを nil にして返すこと")
            func readsAnswer() async throws {
                let result = try await client.previewGoalSetup(
                    direction: .lose, inputs: GoalSetup.firstGoalInputs)

                #expect(
                    result
                        == .answered(
                            GoalSetupPreview(canBackCalculate: false, canOfferLoseProposals: nil)))
            }
        }

        @Suite("立て直しの目標の下見")
        struct RestartPreview {
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
                transport = .ok(json: #"{"canOfferLoseProposals":true}"#)
                client = GoalSetup.client(transport: transport)
            }

            @Test("摂取エネルギーも身体データも送らないこと")
            func sendsNoBodyValues() async throws {
                _ = try await client.previewGoalSetup(
                    direction: .gain,
                    inputs: GoalSetupInputs(
                        timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                        preUseEnergyIntakes: nil, body: nil))

                let body = try JSONDecoder().decode(
                    [String: String].self, from: Data((transport.requests.first?.body ?? "").utf8))
                #expect(body == ["timeZone": "Asia/Tokyo", "direction": "gain"])
            }
        }

        @Suite("サーバーが値を受け付けなかったとき")
        struct Rejected {
            let client: NuToriAPIClient

            init() {
                client = GoalSetup.client(
                    transport: .ok(
                        status: .unprocessableContent, json: #"{"code":"body_data_out_of_range"}"#))
            }

            @Test("理由のコードを返すこと")
            func returnsCode() async throws {
                let result = try await client.previewGoalSetup(
                    direction: .lose, inputs: GoalSetup.firstGoalInputs)

                #expect(result == .unprocessable(code: "body_data_out_of_range"))
            }
        }

        @Suite("減量の目標案")
        struct WeightChangeProposals {
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
                transport = .ok(json: GoalSetup.weightChangeProposalsJSON)
                client = GoalSetup.client(transport: transport)
            }

            @Test("向きと期限を POST /v1/goal-setup/proposals に送ること")
            func sendsDeadline() async throws {
                _ = try await client.proposeGoals(
                    direction: .lose, deadlineOn: "2026-03-31", inputs: GoalSetup.firstGoalInputs)

                let sent = try #require(transport.requests.first)
                #expect(sent.request.path == "/v1/goal-setup/proposals")
                let body = try JSONDecoder().decode(
                    Operations.ProposeGoals.Input.Body.JsonPayload.self,
                    from: Data((sent.body ?? "").utf8))
                #expect(body.direction == .lose)
                #expect(body.deadlineOn == "2026-03-31")
            }

            @Test("3つの枠と出せない理由、受け付ける幅、推定消費カロリーと出どころを読むこと")
            func readsProposals() async throws {
                let result = try await client.proposeGoals(
                    direction: .lose, deadlineOn: "2026-03-31", inputs: GoalSetup.firstGoalInputs)

                let standard = GoalProposals.OfferedProposal(
                    pace: .standard, targetWeightKilograms: 65.5,
                    dailyGuide: DailyGuidePlan(
                        energyKilocalories: 1850, proteinGrams: 105, fatGrams: 50,
                        carbohydrateGrams: 245),
                    difficulty: .standard, dailyGuideDifferenceKilocalories: -400)
                let gentle = GoalProposals.OfferedProposal(
                    pace: .gentle, targetWeightKilograms: 67.7,
                    dailyGuide: DailyGuidePlan(
                        energyKilocalories: 2050, proteinGrams: 110, fatGrams: 55,
                        carbohydrateGrams: 280),
                    difficulty: .gentle, dailyGuideDifferenceKilocalories: -200)
                #expect(
                    result
                        == .answered(
                            GoalProposals(
                                startedOn: "2026-01-01",
                                expenditureKilocalories: 2250,
                                expenditureSource: .backCalculated,
                                startingWeightTrendKilograms: 70.04,
                                lastWeightRecordedOn: "2025-12-31",
                                plan: .weightChange(
                                    .init(
                                        direction: .lose,
                                        deadlineOn: "2026-03-31",
                                        proposals: [
                                            .init(pace: .gentle, availability: .offered(gentle)),
                                            .init(pace: .standard, availability: .offered(standard)),
                                            .init(
                                                pace: .hard,
                                                availability: .unavailable(.dailyGuideBelowMinimum)),
                                        ],
                                        acceptedTargetWeightRange: .init(
                                            minimumKilograms: 64.1, maximumKilograms: 69.9,
                                            fastestEndReason: .dailyGuideBelowMinimum))))))
            }
        }

        @Suite("維持の目標案")
        struct MaintenanceProposals {
            let client: NuToriAPIClient

            init() {
                client = GoalSetup.client(
                    transport: .ok(
                        json: """
                            {"startedOn":"2026-01-01","direction":"maintain","expenditureKcal":2250,
                            "expenditureSource":"formula","startingWeightTrendKg":65.0,
                            "lastWeightRecordedOn":"2026-01-01",
                            "maintenance":{"targetWeightKg":65.0,
                            "dailyGuide":{"energyKcal":2250,"proteinG":105,"fatG":60,"carbohydrateG":320}}}
                            """))
            }

            @Test("目標体重と1日の目安を読むこと")
            func readsMaintenance() async throws {
                let result = try await client.proposeGoals(
                    direction: .maintain, deadlineOn: nil, inputs: GoalSetup.firstGoalInputs)

                guard case .answered(let proposals) = result else {
                    Issue.record("答えが無い")
                    return
                }
                #expect(proposals.expenditureSource == .formula)
                #expect(
                    proposals.plan
                        == .maintenance(
                            .init(
                                targetWeightKilograms: 65.0,
                                dailyGuide: DailyGuidePlan(
                                    energyKilocalories: 2250, proteinGrams: 105, fatGrams: 60,
                                    carbohydrateGrams: 320))))
            }
        }

        @Suite("自分で決める目標体重")
        struct CustomTargetWeight {
            @Suite("受け付けるとき")
            struct Accepted {
                let transport: ClientTransportMock
                let client: NuToriAPIClient

                init() {
                    transport = .ok(
                        json: """
                            {"startedOn":"2026-01-01","status":"accepted",
                            "dailyGuide":{"energyKcal":1900,"proteinG":105,"fatG":50,"carbohydrateG":255},
                            "difficulty":"standard","dailyGuideDifferenceKcal":-350}
                            """)
                    client = GoalSetup.client(transport: transport)
                }

                @Test("向き・期限・目標体重を POST /v1/goal-setup/custom-target-weight に送ること")
                func sendsTargetWeight() async throws {
                    _ = try await client.assessCustomTargetWeight(
                        direction: .lose, deadlineOn: "2026-03-31", targetWeightKilograms: 66.2,
                        inputs: GoalSetup.firstGoalInputs)

                    let sent = try #require(transport.requests.first)
                    #expect(sent.request.path == "/v1/goal-setup/custom-target-weight")
                    let body = try JSONDecoder().decode(
                        Operations.AssessCustomTargetWeight.Input.Body.JsonPayload.self,
                        from: Data((sent.body ?? "").utf8))
                    #expect(body.direction == .lose)
                    #expect(body.deadlineOn == "2026-03-31")
                    #expect(body.targetWeightKg == 66.2)
                }

                @Test("1日の目安と大変さを読むこと")
                func readsAccepted() async throws {
                    let result = try await client.assessCustomTargetWeight(
                        direction: .lose, deadlineOn: "2026-03-31", targetWeightKilograms: 66.2,
                        inputs: GoalSetup.firstGoalInputs)

                    #expect(
                        result
                            == .answered(
                                CustomTargetWeightAssessment(
                                    startedOn: "2026-01-01",
                                    outcome: .accepted(
                                        .init(
                                            dailyGuide: DailyGuidePlan(
                                                energyKilocalories: 1900, proteinGrams: 105,
                                                fatGrams: 50, carbohydrateGrams: 255),
                                            difficulty: .standard,
                                            dailyGuideDifferenceKilocalories: -350)))))
                }
            }

            @Suite("受け付けないとき")
            struct Rejected {
                let client: NuToriAPIClient

                init() {
                    client = GoalSetup.client(
                        transport: .ok(
                            json: """
                                {"startedOn":"2026-01-01","status":"rejected",
                                "rejectionReason":"pace_too_fast","nearestAcceptedTargetWeightKg":64.1}
                                """))
                }

                @Test("理由といちばん近い目標体重を読むこと")
                func readsRejected() async throws {
                    let result = try await client.assessCustomTargetWeight(
                        direction: .lose, deadlineOn: "2026-03-31", targetWeightKilograms: 60,
                        inputs: GoalSetup.firstGoalInputs)

                    #expect(
                        result
                            == .answered(
                                CustomTargetWeightAssessment(
                                    startedOn: "2026-01-01",
                                    outcome: .rejected(
                                        reason: .paceTooFast,
                                        nearestAcceptedTargetWeightKilograms: 64.1))))
                }
            }
        }

        @Suite("目標を決める")
        struct Decide {
            static let request = GoalDecisionRequest(
                requestId: UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!,
                startedOn: "2026-01-01",
                choice: .proposal(direction: .lose, deadlineOn: "2026-03-31", pace: .standard),
                shownTargetWeightKilograms: 65.5,
                shownDailyGuide: DailyGuidePlan(
                    energyKilocalories: 1850, proteinGrams: 105, fatGrams: 50,
                    carbohydrateGrams: 245),
                rejectedCustomTargetWeightCount: 2)

            @Suite("決めたとき")
            struct Decided {
                let transport: ClientTransportMock
                let client: NuToriAPIClient

                init() {
                    transport = .ok(
                        json: """
                            {"status":"decided","changes":[
                            {"kind":"goal","recordId":"\(GoalSetup.goalId)","record":{
                            "id":"\(GoalSetup.goalId)","startedOn":"2026-01-01","startingWeightTrendKg":70.04,
                            "targetWeightKg":65.5,"decidedAt":1767225600000,"timeZone":"Asia/Tokyo",
                            "direction":"lose","weightChange":{"deadlineOn":"2026-03-31","pacePlan":"standard"}}},
                            {"kind":"daily_guide","recordId":"\(GoalSetup.guideId)","record":{
                            "id":"\(GoalSetup.guideId)","goalId":"\(GoalSetup.goalId)",
                            "expenditureEstimateId":"\(GoalSetup.estimateId)","effectiveOn":"2026-01-01",
                            "energyKcal":1850,"proteinG":105,"fatG":50,"carbohydrateG":245,"limitHits":[]}},
                            {"kind":"expenditure_estimate","recordId":"\(GoalSetup.estimateId)","record":{
                            "id":"\(GoalSetup.estimateId)","effectiveOn":"2026-01-01","expenditureKcal":2250,
                            "estimatedAt":1767225600000,"initialSource":"back_calculated"}}]}
                            """)
                    client = GoalSetup.client(transport: transport)
                }

                @Test("要求の ID・開始の日・選んだ案・見せていた値・直した回数を POST /v1/goal-setup/decisions に送ること")
                func sendsDecision() async throws {
                    _ = try await client.decideGoal(Decide.request, inputs: GoalSetup.firstGoalInputs)

                    let sent = try #require(transport.requests.first)
                    #expect(sent.request.path == "/v1/goal-setup/decisions")
                    let body = try JSONDecoder().decode(
                        Operations.DecideGoal.Input.Body.JsonPayload.self,
                        from: Data((sent.body ?? "").utf8))
                    #expect(body.requestId == "00000000-0000-4000-8000-0000000000b1")
                    #expect(body.startedOn == "2026-01-01")
                    #expect(
                        body.choice
                            == .proposal(
                                .init(
                                    _type: .proposal, direction: .lose, deadlineOn: "2026-03-31",
                                    pace: .standard)))
                    #expect(
                        body.shown
                            == .init(
                                targetWeightKg: 65.5,
                                dailyGuide: .init(
                                    energyKcal: 1850, proteinG: 105, fatG: 50, carbohydrateG: 245)))
                    #expect(body.rejectedCustomTargetWeightCount == 2)
                }

                @Test("記録を、取りに行った変更と同じ形で、届いた順に返すこと")
                func readsChanges() async throws {
                    let result = try await client.decideGoal(
                        Decide.request, inputs: GoalSetup.firstGoalInputs)

                    guard case .answered(.decided(let changes)) = result else {
                        Issue.record("決めた答えが無い")
                        return
                    }
                    #expect(changes.map(\.recordKind) == [.goal, .dailyGuide, .expenditureEstimate])
                    guard case .goal(let goal) = changes.first else {
                        Issue.record("目標が無い")
                        return
                    }
                    #expect(
                        goal.direction
                            == .lose(.init(deadlineOn: "2026-03-31", pacePlan: .standard)))
                }
            }

            @Suite("計算し直したとき")
            struct Recalculated {
                let client: NuToriAPIClient

                init() {
                    client = GoalSetup.client(
                        transport: .ok(
                            json: #"{"status":"recalculated","proposals":"#
                                + GoalSetup.weightChangeProposalsJSON + "}"))
                }

                @Test("新しい目標案を返すこと")
                func readsProposals() async throws {
                    let result = try await client.decideGoal(
                        Decide.request, inputs: GoalSetup.firstGoalInputs)

                    guard case .answered(.recalculated(let proposals)) = result else {
                        Issue.record("計算し直した答えが無い")
                        return
                    }
                    #expect(proposals.startedOn == "2026-01-01")
                }
            }

            @Suite("自分で決めた目標体重を受け付けなかったとき")
            struct CustomRejected {
                let client: NuToriAPIClient

                init() {
                    client = GoalSetup.client(
                        transport: .ok(
                            json: """
                                {"status":"custom_target_weight_rejected","startedOn":"2026-01-02",
                                "rejectionReason":"not_on_direction_side"}
                                """))
                }

                @Test("理由を返し、いちばん近い目標体重が無ければ nil にすること")
                func readsRejection() async throws {
                    let result = try await client.decideGoal(
                        Decide.request, inputs: GoalSetup.firstGoalInputs)

                    #expect(
                        result
                            == .answered(
                                .customTargetWeightRejected(
                                    startedOn: "2026-01-02", reason: .notOnDirectionSide,
                                    nearestAcceptedTargetWeightKilograms: nil)))
                }
            }
        }
    }
}
