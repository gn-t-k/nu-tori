#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: GoalLinkCapsuleButton.Sample.allCases) { sample in
        if let capsule = sample.capsule {
            GoalLinkCapsuleButton(capsule: capsule, open: {})
                .padding()
        }
    }

    extension GoalLinkCapsuleButton {
        fileprivate enum Sample: CaseIterable {
            /// 進行中の減量。開始の 72.4 kg から目標の 70.1 kg へ半分ほど進んだ
            case losing
            /// 維持。輪は一周
            case maintaining
            /// 期限より前に達成した。輪は一周
            case achieved

            var capsule: GoalLinkCapsule? {
                let losing = Goal.sampleLosing(
                    startedOn: CalendarDay.sampleToday.advanced(by: -10))
                let status: GoalStatus =
                    switch self {
                    case .losing: .inProgress(losing)
                    case .maintaining: .inProgress(.sampleMaintaining(startedOn: .sampleToday))
                    case .achieved: .achievedBeforeDeadline(losing)
                    }
                return GoalLinkCapsule(
                    status: status, today: .sampleToday,
                    weightTrend: WeightTrend(days: [.init(day: .sampleToday, kilograms: 71.2)]))
            }
        }
    }
#endif
