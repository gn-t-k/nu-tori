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
                answerLater: {},
                open: { _ in }
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    extension GoalSetupNoticeCard {
        fileprivate enum Sample: CaseIterable {
            /// 広げる前の、答えていない知らせ。「あとで」と「目標を立てる」
            case unanswered
            /// 「あとで」で答えたあと。「目標を立てる」だけが残る
            case answeredLater
            /// 途中まで進めて閉じたあと。「続ける」
            case paused
            /// 広げている。中のページごとの形は `GoalSetupFlowCard` のプレビューで見る
            case expanded
            /// 目標が決まったあと。「目標を決めました」の形
            case decided

            var answered: Bool {
                switch self {
                case .unanswered, .expanded: false
                case .answeredLater, .paused, .decided: true
                }
            }

            var currentGoal: CurrentGoal? {
                switch self {
                case .unanswered, .answeredLater, .paused, .expanded: nil
                case .decided: Self.decidedGoal
                }
            }

            private static var decidedGoal: CurrentGoal? {
                let goal = Goal.sampleLosing(startedOn: .sampleToday)
                return CurrentGoal(
                    today: .sampleToday, goals: [goal], dailyGuides: [.sample(for: goal)])
            }

            var flow: GoalSetupNoticeCard.Flow {
                switch self {
                case .unanswered, .answeredLater, .decided: .notStarted
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
        }
    }
#endif
