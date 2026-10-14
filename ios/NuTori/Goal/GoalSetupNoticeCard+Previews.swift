#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: GoalSetupNoticeCard.Sample.allCases) { sample in
        GoalSetupNoticeCard(
            notice: .sampleGoalSetup(on: .sampleToday, answered: sample.answered),
            goal: sample.goal,
            dailyGuide: sample.goal.map { .sample(for: $0) },
            session: .preview,
            timeZone: DeviceClock.live.timeZone,
            open: { _ in }
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    extension GoalSetupNoticeCard {
        fileprivate enum Sample: CaseIterable {
            /// 広げる前の、答えていない知らせ。「あとで」と「目標を立てる」
            case unanswered
            /// 「あとで」で答えたあと。「目標を立てる」だけが残る
            case answeredLater
            /// 目標が決まったあと。「目標を決めました」の形
            case decided

            var answered: Bool {
                switch self {
                case .unanswered: false
                case .answeredLater, .decided: true
                }
            }

            var goal: Goal? {
                switch self {
                case .unanswered, .answeredLater: nil
                case .decided: .sampleLosing(startedOn: .sampleToday)
                }
            }
        }
    }
#endif
