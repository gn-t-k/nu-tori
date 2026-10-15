#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: GoalSetupNoticeCard.Sample.allCases) { sample in
        ScrollView {
            GoalSetupNoticeCard(
                notice: .sampleGoalSetup(on: .sampleToday, answered: sample.answered),
                currentGoal: sample.currentGoal,
                flow: sample.flow,
                timeZone: DeviceClock.live.timeZone,
                open: { _ in }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    extension GoalSetupNoticeCard {
        fileprivate enum Sample: CaseIterable {
            /// 広げる前の、答えていない知らせ。「目標を立てる」
            case unanswered
            /// 途中まで進めて閉じたあと。「続ける」
            case paused
            /// 広げている。中のページごとの形は `GoalSetupFlowCard` のプレビューで見る
            case expanded
            /// 目標が決まったあと。「目標を決めました」の形
            case decided

            var answered: Bool {
                switch self {
                case .unanswered, .paused, .expanded: false
                case .decided: true
                }
            }

            var currentGoal: CurrentGoal? {
                switch self {
                case .unanswered, .paused, .expanded: nil
                case .decided: Self.decidedGoal
                }
            }

            var flow: GoalSetupNoticeCard.Flow {
                switch self {
                case .unanswered, .decided: .notStarted
                case .paused: .paused
                case .expanded:
                    .expanded(
                        GoalSetupFlowContent(
                            page: .direction, progress: .init(count: 3, index: 0), direction: nil,
                            deadline: GoalDeadlineChoices(startDay: .sampleToday).initialDay,
                            deadlineChoices: GoalDeadlineChoices(startDay: .sampleToday),
                            missingValues: nil, proposals: nil, selectedPace: nil,
                            customTargetWeight: nil, decision: .idle, unreachableRequest: nil,
                            showsRecalculated: false, usedValues: nil, pastWeightRecordDay: nil),
                        .none)
                }
            }

            private static var decidedGoal: CurrentGoal? {
                let goal = Goal.sampleLosing(startedOn: .sampleToday)
                return CurrentGoal(
                    today: .sampleToday, goals: [goal], dailyGuides: [.sample(for: goal)])
            }
        }
    }
#endif
