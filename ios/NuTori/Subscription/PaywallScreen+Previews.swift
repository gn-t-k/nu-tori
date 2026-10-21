#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    // 商品は StoreKit の設定ファイルが無いと出ず、自前の宣伝の部分とまとめだけを描く
    #Preview("状態ごと", arguments: PaywallScreen.Sample.allCases) { sample in
        PaywallScreen(
            content: sample.content,
            storefront: .storeKit,
            purchaseToken: sample.purchaseToken,
            message: sample.message,
            purchaseCompleted: { _ in },
            purchaseFailed: {},
            restore: {},
            onClose: {}
        )
    }

    extension PaywallScreen {
        fileprivate enum Sample: CaseIterable {
            case freeTrial
            case expired
            /// サブスクリプション中に開いた（月額と年額の切り替え）
            case subscribed
            /// 購入者のトークンを受け取っている途中
            case requestingToken
            /// 電波が無く、購入者のトークンを受け取れなかった
            case tokenUnreachable
            /// 買ったが、ほかのアカウントのサブスクリプションだった
            case ownedByOtherAccount

            var content: PaywallContent {
                let standing: SubscriptionStanding =
                    switch self {
                    case .freeTrial, .requestingToken:
                        .freeTrial(
                            lastDay: CalendarDay.sampleToday.advanced(by: 9), remainingDays: 10)
                    case .expired, .tokenUnreachable, .ownedByOtherAccount:
                        .expired
                    case .subscribed:
                        .subscribed(plan: .monthly, periodEndsAt: .now, endsAt: .now)
                    }
                return PaywallContent(standing: standing, today: .sampleToday)!
            }

            var purchaseToken: PaywallSession.PurchaseToken {
                switch self {
                case .freeTrial, .expired, .subscribed, .ownedByOtherAccount: .issued(UUID())
                case .requestingToken: .requesting
                case .tokenUnreachable: .unavailable
                }
            }

            var message: String? {
                switch self {
                case .freeTrial, .expired, .subscribed, .requestingToken: nil
                case .tokenUnreachable:
                    "インターネットにつながらないため、今は始められません。つながるところで、もう一度開いてください。"
                case .ownedByOtherAccount: "このサブスクリプションは、ほかの nu-tori のアカウントで使っています"
                }
            }
        }
    }
#endif
