import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import Testing

@MainActor
@Suite("目標の設定の流れ")
struct GoalSetupFlowTests {
    typealias JSON = GoalSetupJSON

    @MainActor
    @Suite("どのページを出すか")
    struct Pages {
        @MainActor
        @Suite("初めてで逆算できる人が減量を選んだとき")
        struct FirstBackCalculable {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                    ],
                    health: .ok(goalSetup: .init(requestStatus: .notYetRequested)))
            }

            @Test("期限のページを、点3つの2つめとして出すこと")
            func showsDeadline() async {
                await harness.flow.chooseDirection(.lose)

                #expect(harness.flow.page == .deadline)
                #expect(harness.flow.progress == .init(count: 3, index: 1))
            }

            @Test("許可を求め、体重記録を送り切ってから、下見を出すこと")
            func previewsAfterAuthorizationAndSending() async throws {
                await harness.flow.chooseDirection(.lose)

                #expect(harness.health.goalSetupAuthorizationRequests == 1)
                #expect(harness.records.calls == [.sendWeightRecords])
                let preview = try #require(try harness.sentBodies("preview").first)
                #expect(preview["direction"] as? String == "lose")
                #expect(preview["preUseEnergyIntakes"] as? [Any] != nil)
            }

            @Test("期限の「次へ」で、期限を載せた目標案を受け取って目標案のページを出すこと")
            func showsProposals() async throws {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                #expect(harness.flow.page == .proposals)
                #expect(harness.flow.progress == .init(count: 3, index: 2))
                #expect(
                    (try harness.sentBodies("proposals").first?["plan"] as? [String: Any])?[
                        "deadlineOn"]
                        as? String
                        == "2026-04-01")
            }

            @Test("今日の体重の記録が無ければ、目標案に使った最後の体重記録の日を見せること")
            func showsPastWeightRecordDay() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                #expect(
                    harness.flow.pastWeightRecordDay == CalendarDay(year: 2025, month: 12, day: 31))
            }

            @Test("今日の体重の記録があれば、最後の体重記録の日を見せないこと")
            func hidesTodaysWeightRecordDay() async {
                harness.server.replace(
                    "proposals",
                    with: .json(JSON.loseProposals(lastWeightRecordedOn: "2026-01-01")))
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                #expect(harness.flow.pastWeightRecordDay == nil)
            }

            @Test("許可を2回は求めないこと")
            func asksAuthorizationOnce() async {
                await harness.flow.chooseDirection(.lose)
                harness.flow.goBack()
                await harness.flow.chooseDirection(.gain)

                #expect(harness.health.goalSetupAuthorizationRequests == 1)
            }
        }

        @MainActor
        @Suite("初めてで、期限の「次へ」までに下見の答えが届かないとき")
        struct PreviewPending {
            let harness: GoalSetupFlowHarness
            let gate: GoalSetupServerStub.Gate

            init() {
                let gate = GoalSetupServerStub.Gate()
                self.gate = gate
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .held(
                                gate,
                                json: JSON.preview(
                                    canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                    ])
            }

            @Test("答えを待つ場所を出し、届いたら目標案を出すこと", .timeLimit(.minutes(1)))
            func waitsForPreview() async {
                let choosing = Task { await harness.flow.chooseDirection(.lose) }
                while harness.server.bodies("preview").isEmpty {
                    await Task.yield()
                }
                let proceeding = Task { await harness.flow.proceedFromDeadline() }
                while harness.flow.page == .deadline {
                    await Task.yield()
                }
                #expect(harness.flow.page == .awaitingPreview)

                gate.open()
                await choosing.value
                await proceeding.value

                #expect(harness.flow.page == .proposals)
                #expect(harness.server.bodies("proposals").count == 1)
            }

            @Test("答えを待つ場所で閉じたら、止まった場所と分けて知らせること", .timeLimit(.minutes(1)))
            func observesAwaitingPreview() async {
                harness.flow.open(from: .noticeCard)
                let choosing = Task { await harness.flow.chooseDirection(.lose) }
                while harness.server.bodies("preview").isEmpty {
                    await Task.yield()
                }
                let proceeding = Task { await harness.flow.proceedFromDeadline() }
                while harness.flow.page == .deadline {
                    await Task.yield()
                }

                harness.flow.close()
                gate.open()
                await choosing.value
                await proceeding.value

                #expect(harness.observations.all.last == .closed(page: .awaitingPreview))
            }
        }

        @MainActor
        @Suite("初めてで逆算できず、体重の記録が無い人が減量を選んだとき")
        struct FirstNotBackCalculable {
            let harness: GoalSetupFlowHarness
            let entry: GoalSetupMissingValues.Entry

            init() {
                harness = GoalSetupFlowHarness(
                    start: .first(
                        firstUseDay: CalendarDay(year: 2025, month: 12, day: 20),
                        hasWeightRecords: false),
                    answers: [
                        "preview": [
                            .json(
                                JSON.preview(canBackCalculate: false, canOfferLoseProposals: nil)),
                            .json(
                                JSON.preview(canBackCalculate: false, canOfferLoseProposals: true)),
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                    ],
                    health: .ok(
                        goalSetup: .init(
                            dateOfBirth: CalendarDay(year: 1990, month: 6, day: 1), sex: .female)))
                entry = GoalSetupMissingValues.Entry(
                    heightCentimeters: 160, birthYear: nil, sex: nil, activityLevel: .standing,
                    currentWeightKilograms: 70.2)
            }

            @Test("期限のページにいるあいだに、点が1つ増えること")
            func addsDotOnDeadline() async {
                await harness.flow.chooseDirection(.lose)

                #expect(harness.flow.page == .deadline)
                #expect(harness.flow.progress == .init(count: 4, index: 1))
            }

            @Test("期限の次に、ヘルスケアから取れなかった値と今の体重だけを尋ねること")
            func asksMissingValues() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                #expect(harness.flow.page == .missingValues)
                #expect(
                    harness.flow.missingValues?.asked == [.height, .activityLevel, .currentWeight])
            }

            @Test("そろうまで「次へ」で進まないこと")
            func staysUntilComplete() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.enterMissingValues(
                    .init(
                        heightCentimeters: 99, birthYear: nil, sex: nil, activityLevel: .standing,
                        currentWeightKilograms: 70.2))

                await harness.flow.proceedFromMissingValues()

                #expect(harness.flow.missingValues?.isComplete == false)
                #expect(harness.flow.page == .missingValues)
            }

            @Test("今の体重を記録して送り切ってから、身体データを添えて下見を出し直し、目標案を出すこと")
            func recordsWeightAndPreviewsAgain() async throws {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.enterMissingValues(entry)

                await harness.flow.proceedFromMissingValues()

                #expect(
                    harness.records.calls == [
                        .sendWeightRecords, .recordWeight(kilograms: 70.2), .sendWeightRecords,
                    ])
                let body = try #require(
                    try harness.sentBodies("preview").last?["bodyData"] as? [String: Any])
                #expect(body["heightCentimeters"] as? Double == 160)
                #expect(body["ageYears"] as? Int == 35)
                #expect(body["sex"] as? String == "female")
                #expect(try harness.sentBodies("proposals").first?["bodyData"] != nil)
                #expect(harness.flow.page == .proposals)
                #expect(harness.flow.progress == .init(count: 4, index: 3))
            }

            @Test("目標案の上の1行に、足りない値の「次へ」で決めた身体データを見せること")
            func showsUsedBody() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.enterMissingValues(entry)

                await harness.flow.proceedFromMissingValues()

                #expect(
                    harness.flow.submittedBody
                        == GoalSetupBody(
                            sex: .female, heightCentimeters: 160, ageYears: 35,
                            activity: .level(.standing)))
            }

            @Test("自分で決める目標体重のページの「変える」で、答えを残して足りない値のページに戻ること")
            func revisesMissingValuesFromCustom() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.enterMissingValues(entry)
                await harness.flow.proceedFromMissingValues()
                harness.flow.openCustomTargetWeight()

                harness.flow.reviseMissingValues()

                #expect(harness.flow.page == .missingValues)
                #expect(harness.flow.missingValues?.entry == entry)
            }
        }

        @MainActor
        @Suite("維持を選んだとき")
        struct Maintain {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: nil))
                        ],
                        "proposals": [.json(JSON.maintenance())],
                    ])
            }

            @Test("期限を通らずに、期限を載せない目標案で維持のページを出すこと")
            func skipsDeadline() async throws {
                await harness.flow.chooseDirection(.maintain)

                #expect(harness.flow.page == .maintenance)
                #expect(harness.flow.progress == .init(count: 2, index: 1))
                let plan = try harness.sentBodies("proposals").first?["plan"] as? [String: Any]
                #expect(plan?["direction"] as? String == "maintain")
                #expect(plan?["deadlineOn"] == nil)
                guard case .maintenance(let maintenance)? = harness.flow.proposals?.plan else {
                    Issue.record("維持の値が無い")
                    return
                }
                #expect(maintenance.dailyGuide.energyKilocalories == 2250)
            }
        }

        @MainActor
        @Suite("立て直すとき")
        struct Restart {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    start: .restart(
                        currentGoalStartedDay: CalendarDay(year: 2025, month: 11, day: 1)),
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: nil, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                    ],
                    health: .ok(goalSetup: .init(requestStatus: .notYetRequested)))
            }

            @Test("許可を求めず、体重記録を送らず、摂取エネルギーを載せずに下見を出すこと")
            func previewsWithoutFirstGoalValues() async throws {
                await harness.flow.chooseDirection(.lose)

                #expect(harness.health.goalSetupAuthorizationRequests == 0)
                #expect(harness.records.calls.isEmpty)
                #expect(try harness.sentBodies("preview").first?["preUseEnergyIntakes"] == nil)
            }

            @Test("足りない値を出さずに、期限の次で目標案を出すこと")
            func showsProposalsAfterDeadline() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                #expect(harness.flow.page == .proposals)
                #expect(harness.flow.progress == .init(count: 3, index: 2))
            }
        }

        @MainActor
        @Suite("逆算できる人が、減量の案を1つも出せないとき")
        struct LoseUnavailableBackCalculable {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(
                                JSON.preview(canBackCalculate: true, canOfferLoseProposals: false))
                        ],
                        "proposals": [.json(JSON.maintenance())],
                    ])
            }

            @Test("減量を選んだ次の場所で断り、逆算できたことを知らせること")
            func refusesBeforeDeadline() async {
                await harness.flow.chooseDirection(.lose)

                #expect(harness.flow.page == .loseUnavailable)
                #expect(harness.flow.progress == .init(count: 2, index: 1))
                #expect(harness.observations.all == [.plansUnavailable(canBackCalculate: true)])
            }

            @Test("「維持にする」で維持のページを出すこと")
            func switchesToMaintain() async {
                await harness.flow.chooseDirection(.lose)

                await harness.flow.chooseMaintainInstead()

                #expect(harness.flow.direction == .maintain)
                #expect(harness.flow.page == .maintenance)
            }

            @Test("「戻る」で向きのページに戻ること")
            func goesBackToDirection() async {
                await harness.flow.chooseDirection(.lose)

                harness.flow.goBack()

                #expect(harness.flow.page == .direction)
            }
        }

        @MainActor
        @Suite("逆算できない人が、減量の案を1つも出せないとき")
        struct LoseUnavailableNotBackCalculable {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(
                                JSON.preview(canBackCalculate: false, canOfferLoseProposals: nil)),
                            .json(
                                JSON.preview(canBackCalculate: false, canOfferLoseProposals: false)),
                        ]
                    ],
                    health: .ok(
                        goalSetup: .init(
                            dailySteps: [CalendarDay(year: 2025, month: 12, day: 30): 6000],
                            heightCentimeters: 160,
                            dateOfBirth: CalendarDay(year: 1990, month: 6, day: 1), sex: .female)))
            }

            @Test("足りない値の「次へ」のあとで断ること")
            func refusesAfterMissingValues() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                #expect(harness.flow.page == .missingValues)

                await harness.flow.proceedFromMissingValues()

                #expect(harness.flow.page == .loseUnavailable)
                #expect(harness.flow.progress == .init(count: 4, index: 3))
                #expect(harness.observations.all == [.plansUnavailable(canBackCalculate: false)])
            }
        }
    }

    @MainActor
    @Suite("電波がないとき")
    struct Offline {
        @MainActor
        @Suite("初めてで、体重記録を送り切れないとき")
        struct WeightRecordsUnsent {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                    ],
                    records: .ok(sendsWeightRecords: false))
            }

            @Test("向きと期限には答えられ、足りない値より前で止まり、下見を出さないこと")
            func stopsBeforeMissingValues() async {
                await harness.flow.chooseDirection(.lose)
                #expect(harness.flow.page == .deadline)

                await harness.flow.proceedFromDeadline()

                #expect(harness.flow.page == .stopped(.beforeMissingValues))
                #expect(harness.server.bodies("preview").isEmpty)
            }

            @Test("つながってから「もう一度試す」で、選んだ期限のまま目標案を出すこと")
            func retries() async throws {
                await harness.flow.chooseDirection(.lose)
                harness.flow.chooseDeadline(CalendarDay(year: 2026, month: 3, day: 1))
                await harness.flow.proceedFromDeadline()
                harness.records.sendsWeightRecords = true

                await harness.flow.retry()

                #expect(harness.flow.page == .proposals)
                #expect(
                    (try harness.sentBodies("proposals").first?["plan"] as? [String: Any])?[
                        "deadlineOn"]
                        as? String
                        == "2026-03-01")
            }

            @Test("閉じて開き直すと、同じ止まった場所から続けること")
            func resumes() async {
                harness.flow.open(from: .noticeCard)
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                harness.flow.close()
                harness.flow.open(from: .unansweredNoticeLine)

                #expect(harness.flow.page == .stopped(.beforeMissingValues))
                #expect(
                    harness.observations.all == [
                        .opened(entry: .noticeCard, isRestart: false, resumed: false),
                        .closed(page: .stopped),
                        .opened(entry: .unansweredNoticeLine, isRestart: false, resumed: true),
                    ])
            }
        }

        @MainActor
        @Suite("逆算できると分かったあと、目標案が届かないとき")
        struct ProposalsUnreachable {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.offline, .json(JSON.loseProposals())],
                    ])
            }

            @Test("目標案の前で止まり、「もう一度試す」で目標案を出すこと")
            func stopsBeforeProposals() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                #expect(harness.flow.page == .stopped(.beforeProposals))

                await harness.flow.retry()

                #expect(harness.flow.page == .proposals)
            }
        }
    }

    @MainActor
    @Suite("目標案を開くとき")
    struct OpeningProposal {
        @MainActor
        @Suite("標準が出るとき")
        struct StandardOffered {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                    ])
            }

            @Test("標準を選んで開くこと")
            func selectsStandard() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                #expect(harness.flow.selectedPace == .standard)
            }
        }

        @MainActor
        @Suite("標準が出ないとき")
        struct StandardUnavailable {
            let harness: GoalSetupFlowHarness

            init() {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [
                            .json(
                                JSON.loseProposals(offered: [
                                    "gentle": (68.5, 1300), "hard": (64.5, 1200),
                                ]))
                        ],
                    ])
            }

            @Test("出せる案のうち最もゆるい案を選んで開くこと")
            func selectsGentlest() async {
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()

                #expect(harness.flow.selectedPace == .gentle)
            }
        }
    }

    @MainActor
    @Suite("自分で決める目標体重")
    struct Custom {
        let harness: GoalSetupFlowHarness
        let firstGate: GoalSetupServerStub.Gate

        init() async {
            let firstGate = GoalSetupServerStub.Gate()
            self.firstGate = firstGate
            harness = GoalSetupFlowHarness(
                answers: [
                    "preview": [
                        .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                    ],
                    "proposals": [.json(JSON.loseProposals())],
                    "custom-target-weight": [
                        .held(firstGate, json: JSON.acceptedCustom(energyKcal: 1900)),
                        .json(JSON.acceptedCustom(energyKcal: 1800)),
                    ],
                    "decisions": [.json(JSON.decided)],
                ])
            await harness.flow.chooseDirection(.lose)
            await harness.flow.proceedFromDeadline()
            harness.flow.openCustomTargetWeight()
        }

        @Test("標準の案の目標体重と1日の目安で開くこと")
        func opensWithStandard() throws {
            let custom = try #require(harness.flow.customTargetWeight)
            #expect(custom.kilograms == 66.5)
            #expect(custom.assessment.dailyGuide.energyKilocalories == 1850)
            #expect(harness.flow.page == .customTargetWeight)
        }

        @Test("動かしてから 0.3 秒たつまで要求を出さず、届くまで答えを待つ形にすること", .timeLimit(.minutes(1)))
        func waitsBeforeRequest() async throws {
            let moving = Task { await harness.flow.setCustomTargetWeight(66.0) }
            await harness.clock.advance(by: .milliseconds(299))

            #expect(harness.server.bodies("custom-target-weight").isEmpty)
            #expect(harness.flow.customTargetWeight?.isAssessing == true)
            firstGate.open()
            await harness.clock.advance(by: .milliseconds(1))
            await moving.value
            #expect(
                try harness.sentBodies("custom-target-weight").first?["targetWeightKg"] as? Double
                    == 66.0)
            #expect(harness.flow.customTargetWeight?.isAssessing == false)
        }

        @Test("届いた順が入れ替わっても、最後に出した要求の答えだけを使うこと", .timeLimit(.minutes(1)))
        func usesLatestAnswer() async {
            let first = Task { await harness.flow.setCustomTargetWeight(66.0) }
            await harness.clock.advance(by: .milliseconds(300))
            let second = Task { await harness.flow.setCustomTargetWeight(65.0) }
            await harness.clock.advance(by: .milliseconds(300))
            await second.value
            firstGate.open()
            await first.value

            #expect(harness.flow.customTargetWeight?.kilograms == 65.0)
            #expect(
                harness.flow.customTargetWeight?.assessment.dailyGuide.energyKilocalories == 1800)
        }

        @Test("受け付ける幅の外は端の値に直し、直した回数を目標を決める要求に載せること", .timeLimit(.minutes(1)))
        func clampsAndCounts() async throws {
            firstGate.open()
            let moving = Task { await harness.flow.setCustomTargetWeight(60.0) }
            await harness.clock.advance(by: .milliseconds(300))
            await moving.value

            #expect(harness.flow.customTargetWeight?.kilograms == 64.0)
            #expect(harness.flow.customTargetWeight?.correctedReason == .paceTooFast)
            #expect(harness.flow.customTargetWeight?.canDecrease == false)
            await harness.flow.decide()
            let decision = try #require(try harness.sentBodies("decisions").first)
            #expect(decision["rejectedCustomTargetWeightCount"] as? Int == 1)
        }

        @Test("届く前に押した「この目標で始める」は、届いた値を見せていた値にして決めること", .timeLimit(.minutes(1)))
        func decidesAfterAnswer() async throws {
            let moving = Task { await harness.flow.setCustomTargetWeight(66.0) }
            let deciding = Task { await harness.flow.decide() }
            await harness.clock.advance(by: .milliseconds(300))
            #expect(harness.flow.decision == .deciding)
            #expect(harness.server.bodies("decisions").isEmpty)
            firstGate.open()
            await moving.value
            await deciding.value

            let decision = try #require(try harness.sentBodies("decisions").first)
            let choice = try #require(decision["choice"] as? [String: Any])
            #expect(choice["type"] as? String == "custom")
            #expect(choice["targetWeightKg"] as? Double == 66.0)
            let shown = try #require(decision["shown"] as? [String: Any])
            let guide = try #require(shown["dailyGuide"] as? [String: Any])
            #expect(guide["energyKcal"] as? Int == 1900)
            #expect(harness.flow.decision == .decided)
        }
    }

    @MainActor
    @Suite("自分で決める目標体重の答えが届かなかったあと")
    struct CustomUnreachable {
        @MainActor
        @Suite("「この目標で始める」で問い直した答えが届くとき")
        struct AnsweredOnDecide {
            let harness: GoalSetupFlowHarness

            init() async {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                        "custom-target-weight": [
                            .offline, .json(JSON.acceptedCustom(energyKcal: 1900)),
                        ],
                        "decisions": [.json(JSON.decided)],
                    ])
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.openCustomTargetWeight()
                let flow = harness.flow
                let moving = Task { await flow.setCustomTargetWeight(66.0) }
                await harness.clock.advance(by: .milliseconds(300))
                await moving.value
            }

            @Test("今の目標体重をもう一度問い、届いた1日の目安を見せていた値にして決めること", .timeLimit(.minutes(1)))
            func asksAgainBeforeDeciding() async throws {
                #expect(harness.flow.unreachableRequest == .customTargetWeight)

                await harness.flow.decide()

                let assessed = try harness.sentBodies("custom-target-weight").map {
                    $0["targetWeightKg"] as? Double
                }
                #expect(assessed == [66.0, 66.0])
                let decision = try #require(try harness.sentBodies("decisions").first)
                let shown = try #require(decision["shown"] as? [String: Any])
                let guide = try #require(shown["dailyGuide"] as? [String: Any])
                #expect(guide["energyKcal"] as? Int == 1900)
                #expect(harness.flow.decision == .decided)
            }

            @Test("計算し直しを挟まずに決めたと知らせること", .timeLimit(.minutes(1)))
            func observesWithoutRecalculation() async {
                await harness.flow.decide()

                #expect(harness.flow.showsRecalculated == false)
                #expect(
                    harness.observations.all == [.decided(choice: .custom, recalculated: false)])
            }
        }

        @MainActor
        @Suite("問い直した答えも届かないとき")
        struct UnreachableAgain {
            let harness: GoalSetupFlowHarness

            init() async {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                        "custom-target-weight": [.offline],
                        "decisions": [.json(JSON.decided)],
                    ])
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.openCustomTargetWeight()
                let flow = harness.flow
                let moving = Task { await flow.setCustomTargetWeight(66.0) }
                await harness.clock.advance(by: .milliseconds(300))
                await moving.value
            }

            @Test("決めずに、届かなかった1行と「もう一度試す」を出すこと", .timeLimit(.minutes(1)))
            func stopsWithoutDeciding() async {
                await harness.flow.decide()

                #expect(harness.server.bodies("decisions").isEmpty)
                #expect(harness.flow.unreachableRequest == .customTargetWeight)
                #expect(harness.flow.decision == .idle)
            }
        }
    }

    @MainActor
    @Suite("目標を決めるとき")
    struct Deciding {
        @MainActor
        @Suite("決めたとき")
        struct Decided {
            let harness: GoalSetupFlowHarness

            init() async {
                harness = GoalSetupFlowHarness(
                    start: .first(
                        firstUseDay: CalendarDay(year: 2025, month: 12, day: 20),
                        hasWeightRecords: false),
                    answers: [
                        "preview": [
                            .json(
                                JSON.preview(canBackCalculate: false, canOfferLoseProposals: nil)),
                            .json(
                                JSON.preview(canBackCalculate: false, canOfferLoseProposals: true)),
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                        "decisions": [.json(JSON.decided)],
                    ])
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.enterMissingValues(
                    .init(
                        heightCentimeters: 160, birthYear: 1990, sex: .female,
                        activityLevel: .active,
                        currentWeightKilograms: 70.2))
                await harness.flow.proceedFromMissingValues()
            }

            @Test("選んだ案と見せていた値と開始の日を送ること")
            func sendsChoice() async throws {
                await harness.flow.decide()

                let decision = try #require(try harness.sentBodies("decisions").first)
                #expect(decision["startedOn"] as? String == "2026-01-01")
                let choice = try #require(decision["choice"] as? [String: Any])
                #expect(choice["pace"] as? String == "standard")
                #expect(choice["deadlineOn"] as? String == "2026-04-01")
                let shown = try #require(decision["shown"] as? [String: Any])
                #expect(shown["targetWeightKg"] as? Double == 66.5)
            }

            @Test("応答の記録をキャッシュに書き、知らせに答え、身体データを捨てること")
            func appliesRecords() async throws {
                await harness.flow.decide()

                let applied = harness.records.calls.compactMap { call -> [SyncChange]? in
                    guard case .applyGoalDecision(let changes) = call else { return nil }
                    return changes
                }
                #expect(applied.first?.map(\.kindName) == [.goal])
                #expect(harness.records.calls.last == .respondToGoalSetupNotice)
                #expect(harness.flow.decision == .decided)
                #expect(harness.flow.missingValues == nil)
                #expect(
                    harness.observations.all == [.decided(choice: .standard, recalculated: false)])
            }

            @Test("決まったら閉じること")
            func closesWhenDecided() async {
                harness.flow.open(from: .noticeCard)

                await harness.flow.decide()

                #expect(harness.flow.isOpen == false)
            }
        }

        @MainActor
        @Suite("決めたが、応答の記録をキャッシュに当てられなかったとき（記録は同期で届く）")
        struct DecidedButNotCached {
            let harness: GoalSetupFlowHarness

            init() async {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                        "decisions": [.json(JSON.decided)],
                    ],
                    records: .ok(appliesGoalDecision: false))
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.open(from: .noticeCard)
            }

            @Test("押せないまま残さずに閉じ、知らせに答えること")
            func closes() async {
                await harness.flow.decide()

                #expect(harness.flow.isOpen == false)
                #expect(harness.flow.hasProgress == false)
                #expect(harness.flow.decision == .decided)
                #expect(harness.records.calls.last == .respondToGoalSetupNotice)
            }
        }

        @MainActor
        @Suite("決めずに新しい案が返ったとき")
        struct Recalculated {
            let harness: GoalSetupFlowHarness

            init() async {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                        "decisions": [
                            .json(
                                JSON.recalculated(
                                    JSON.loseProposals(offered: [
                                        "gentle": (68.4, 2000), "standard": (66.3, 1800),
                                        "hard": (64.2, 1600),
                                    ]))),
                            .json(JSON.decided),
                        ],
                    ])
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.selectPace(.hard)
            }

            @Test("選んでいた案を残したまま値を差し替え、計算し直したことを添えること")
            func keepsSelection() async throws {
                await harness.flow.decide()

                #expect(harness.flow.decision == .idle)
                #expect(harness.flow.selectedPace == .hard)
                #expect(harness.flow.showsRecalculated)
                guard case .weightChange(let weightChange)? = harness.flow.proposals?.plan else {
                    Issue.record("目標案が無い")
                    return
                }
                #expect(
                    weightChange.offeredProposals.map(\.targetWeightKilograms) == [
                        68.4, 66.3, 64.2,
                    ])
            }

            @Test("もう一度押すと、同じ要求の ID で決め、計算し直しを挟んだと知らせること")
            func decidesAgain() async throws {
                await harness.flow.decide()
                await harness.flow.decide()

                let ids = try harness.sentBodies("decisions").map { $0["requestId"] as? String }
                #expect(ids.count == 2)
                #expect(Set(ids).count == 1)
                #expect(harness.observations.all == [.decided(choice: .hard, recalculated: true)])
            }
        }

        @MainActor
        @Suite("選んでいた案が、計算し直して出せなくなったとき")
        struct SelectionUnavailable {
            let harness: GoalSetupFlowHarness

            init() async {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                        "decisions": [
                            .json(
                                JSON.recalculated(
                                    JSON.loseProposals(offered: [
                                        "gentle": (68.4, 1400), "standard": (66.3, 1200),
                                    ])))
                        ],
                    ])
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
                harness.flow.selectPace(.hard)
            }

            @Test("開くときと同じ決まりで選び直すこと")
            func reselects() async {
                await harness.flow.decide()

                #expect(harness.flow.selectedPace == .standard)
            }
        }

        @MainActor
        @Suite("決める要求が届かなかったとき")
        struct Unreachable {
            let harness: GoalSetupFlowHarness

            init() async {
                harness = GoalSetupFlowHarness(
                    answers: [
                        "preview": [
                            .json(JSON.preview(canBackCalculate: true, canOfferLoseProposals: true))
                        ],
                        "proposals": [.json(JSON.loseProposals())],
                        "decisions": [.offline, .json(JSON.decided)],
                    ])
                await harness.flow.chooseDirection(.lose)
                await harness.flow.proceedFromDeadline()
            }

            @Test("答えを残してページの中で止まり、「もう一度試す」で同じ要求の ID で送り直すこと")
            func retriesWithSameId() async throws {
                await harness.flow.decide()
                #expect(harness.flow.unreachableRequest == .decision)
                #expect(harness.flow.decision == .idle)
                #expect(harness.flow.selectedPace == .standard)

                await harness.flow.retry()

                let ids = try harness.sentBodies("decisions").map { $0["requestId"] as? String }
                #expect(ids.count == 2)
                #expect(Set(ids).count == 1)
                #expect(harness.flow.decision == .decided)
            }
        }
    }
}
