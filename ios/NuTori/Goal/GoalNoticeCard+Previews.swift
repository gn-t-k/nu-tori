#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: GoalNoticeCard.Sample.allCases) { sample in
        GoalNoticeCard(notice: sample.notice, open: { _ in })
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    extension GoalNoticeCard {
        fileprivate enum Sample: CaseIterable {
            /// 期限より前に達成した。「次の目標を選ぶ」
            case achieved
            /// 期限を迎えた。結果と、期限後の維持に移る月曜
            case deadlineReached
            /// 期限後の維持に移った。「次の目標を立てる」
            case movedToMaintenance
            /// 達成したあと次の目標を決めた。ボタンを押せず、理由の1行を添える
            case switchedAfterAchieved
            /// 期限を迎えたあと期限後の維持に移った。ボタンを押せず、理由の1行を添える
            case movedAfterDeadline

            var notice: GoalNotice {
                switch self {
                case .achieved:
                    GoalNotice(
                        goal: Self.goal, kind: .achieved(Self.achievement), unavailability: nil)
                case .deadlineReached:
                    GoalNotice(
                        goal: Self.goal, kind: .deadlineReached(Self.confirmation),
                        unavailability: nil)
                case .movedToMaintenance:
                    GoalNotice(
                        goal: .sampleMaintaining(
                            startedOn: CalendarDay(year: 2026, month: 12, day: 28)),
                        kind: .movedToMaintenance(previous: Self.goal), unavailability: nil)
                case .switchedAfterAchieved:
                    GoalNotice(
                        goal: Self.goal, kind: .achieved(Self.achievement),
                        unavailability: .switched)
                case .movedAfterDeadline:
                    GoalNotice(
                        goal: Self.goal, kind: .deadlineReached(Self.confirmation),
                        unavailability: .movedToMaintenance)
                }
            }

            private static let goal = Goal.sampleLosing(startedOn: .sampleToday)
            private static let timeZone = TimeZone(identifier: "Asia/Tokyo")!

            private static let achievement = Goal.Achievement(
                achievedDay: CalendarDay(year: 2026, month: 12, day: 2),
                judgedAt: instant(month: 12, day: 2, hour: 7, minute: 5), timeZone: timeZone)

            private static let confirmation = Goal.DeadlineConfirmation(
                deadlineWeightTrendKilograms: 70.5,
                confirmedAt: instant(month: 12, day: 25, hour: 7, minute: 2), timeZone: timeZone)

            private static func instant(month: Int, day: Int, hour: Int, minute: Int) -> Date {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                return calendar.date(
                    from: DateComponents(
                        year: 2026, month: month, day: day, hour: hour, minute: minute))!
            }
        }
    }
#endif
