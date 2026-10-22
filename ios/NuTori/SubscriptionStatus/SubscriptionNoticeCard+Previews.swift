#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: SubscriptionNoticeCard.Sample.allCases) { sample in
        SubscriptionNoticeCard(notice: sample.notice, openPaywall: {})
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    extension SubscriptionNoticeCard {
        fileprivate enum Sample: CaseIterable {
            /// 無料体験のあと3日。「サブスクリプションを見る」がある
            case freeTrialEndsSoon
            /// 無料体験の最後の日。「サブスクリプションを見る」がある
            case freeTrialLastDay
            /// 無料体験が終わった。ボタンは無い
            case freeTrialEnded
            /// サブスクリプションが終わった
            case subscriptionEnded
            /// 作り直したアカウントで、無料体験が無い
            case noFreeTrial

            var notice: SubscriptionNotice {
                let today = CalendarDay.sampleToday
                return switch self {
                case .freeTrialEndsSoon:
                    SubscriptionNotice(
                        kind: .freeTrialEndsSoon(lastDay: today.advanced(by: 2)), day: today)
                case .freeTrialLastDay:
                    SubscriptionNotice(kind: .freeTrialLastDay, day: today)
                case .freeTrialEnded:
                    SubscriptionNotice(kind: .freeTrialEnded, day: today)
                case .subscriptionEnded:
                    SubscriptionNotice(kind: .subscriptionEnded, day: today)
                case .noFreeTrial:
                    SubscriptionNotice(kind: .noFreeTrial, day: today)
                }
            }
        }
    }
#endif
