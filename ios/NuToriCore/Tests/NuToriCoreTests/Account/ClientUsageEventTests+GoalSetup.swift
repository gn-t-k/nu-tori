import NuToriCore
import Testing

extension ClientUsageEventTests {
    @Suite("目標の設定")
    struct GoalSetup {
        @Test("開いたところ、立て直しか、途中から続けたかを載せること")
        func opened() {
            let events: [ClientUsageEvent] = [
                .goalSetup(.opened(entry: .noticeCard, isRestart: false, resumed: false)),
                .goalSetup(.opened(entry: .unansweredNoticeLine, isRestart: false, resumed: true)),
                .goalSetup(.opened(entry: .daySummary, isRestart: true, resumed: false)),
                .goalSetup(.opened(entry: .weightScreen, isRestart: false, resumed: false)),
            ]

            #expect(events.map(\.name) == Array(repeating: "goal_setup_opened", count: 4))
            #expect(
                events.map(\.fields) == [
                    [
                        "entry": .token("notice_card"), "is_restart": .flag(false),
                        "resumed": .flag(false),
                    ],
                    [
                        "entry": .token("unanswered_notice_line"), "is_restart": .flag(false),
                        "resumed": .flag(true),
                    ],
                    [
                        "entry": .token("day_summary"), "is_restart": .flag(true),
                        "resumed": .flag(false),
                    ],
                    [
                        "entry": .token("weight_screen"), "is_restart": .flag(false),
                        "resumed": .flag(false),
                    ],
                ])
            #expect(events.allSatisfy { $0.screenToken == nil })
        }

        @Test("目標の知らせの「次の目標を選ぶ」「次の目標を立てる」から開いたところを載せること")
        func openedFromGoalNotice() {
            let events: [ClientUsageEvent] = [
                .goalSetup(.opened(entry: .chooseNextGoal, isRestart: true, resumed: false)),
                .goalSetup(.opened(entry: .setNextGoal, isRestart: true, resumed: true)),
            ]

            #expect(
                events.map(\.fields) == [
                    [
                        "entry": .token("choose_next_goal"), "is_restart": .flag(true),
                        "resumed": .flag(false),
                    ],
                    [
                        "entry": .token("set_next_goal"), "is_restart": .flag(true),
                        "resumed": .flag(true),
                    ],
                ])
        }

        @Test("目標の画面の「目標を切り替える」から開いたところを載せること")
        func openedFromGoalScreen() {
            let event = ClientUsageEvent.goalSetup(
                .opened(entry: .switchGoal, isRestart: true, resumed: false))

            #expect(
                event.fields == [
                    "entry": .token("switch_goal"), "is_restart": .flag(true),
                    "resumed": .flag(false),
                ])
        }

        @Test("閉じたページを載せること")
        func closed() {
            let pages: [GoalSetupObservation.Page] = [
                .direction, .deadline, .missingValues, .proposals, .customTargetWeight,
                .maintenance, .loseUnavailable, .stopped, .awaitingPreview,
            ]
            let events = pages.map { ClientUsageEvent.goalSetup(.closed(page: $0)) }

            #expect(events.map(\.name) == Array(repeating: "goal_setup_closed", count: 9))
            #expect(
                events.map(\.fields)
                    == [
                        "direction", "deadline", "missing_values", "proposals",
                        "custom_target_weight", "maintenance", "lose_unavailable", "stopped",
                        "awaiting_preview",
                    ].map { ["page": .token($0)] })
        }

        @Test("選んだ案と、計算し直しを挟んだかを載せること")
        func decided() {
            let choices: [GoalSetupObservation.Choice] = [
                .gentle, .standard, .hard, .custom, .maintain,
            ]
            let events = choices.map {
                ClientUsageEvent.goalSetup(.decided(choice: $0, recalculated: $0 == .hard))
            }

            #expect(events.map(\.name) == Array(repeating: "goal_decided", count: 5))
            #expect(
                events.map(\.fields) == [
                    ["choice": .token("gentle"), "recalculated": .flag(false)],
                    ["choice": .token("standard"), "recalculated": .flag(false)],
                    ["choice": .token("hard"), "recalculated": .flag(true)],
                    ["choice": .token("custom"), "recalculated": .flag(false)],
                    ["choice": .token("maintain"), "recalculated": .flag(false)],
                ])
        }

        @Test("案を出せなかったとき、逆算できたかを載せ、立て直しでは載せないこと")
        func plansUnavailable() {
            let events: [ClientUsageEvent] = [
                .goalSetup(.plansUnavailable(canBackCalculate: true)),
                .goalSetup(.plansUnavailable(canBackCalculate: false)),
                .goalSetup(.plansUnavailable(canBackCalculate: nil)),
            ]

            #expect(events.map(\.name) == Array(repeating: "goal_plans_unavailable", count: 3))
            #expect(
                events.map(\.fields) == [
                    ["can_back_calculate": .flag(true)],
                    ["can_back_calculate": .flag(false)],
                    [:],
                ])
        }
    }
}
