#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: GoalDecidedCard.Sample.allCases) { sample in
        GoalDecidedCard(goal: sample.goal, dailyGuide: sample.dailyGuide)
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    extension GoalDecidedCard {
        fileprivate enum Sample: CaseIterable {
            /// 減量で決めた。期限と目標体重、1日の目安と P・F・C の目安
            case losing
            /// 維持で決めた。期限は書かず「65.0 kg を保つ」
            case maintaining
            /// 決めたが、1日の目安がまだ届いていない。目安の行を出さない
            case dailyGuideNotArrived

            var goal: Goal {
                switch self {
                case .losing, .dailyGuideNotArrived: .sampleLosing(startedOn: .sampleToday)
                case .maintaining: .sampleMaintaining(startedOn: .sampleToday)
                }
            }

            var dailyGuide: DailyGuide? {
                switch self {
                case .losing, .maintaining: .sample(for: goal)
                case .dailyGuideNotArrived: nil
                }
            }
        }
    }
#endif
