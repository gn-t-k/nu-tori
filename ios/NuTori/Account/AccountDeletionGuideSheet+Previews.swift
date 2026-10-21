#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: AccountDeletionGuideSheet.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        AccountDeletionGuideSheet(
            guide: sample.guide,
            actions: AccountDeletionGuideSheet.Actions(
                reread: { $0 }, openedManageSubscriptions: {}, proceedToDeletion: {},
                cancel: {})
        )
    }

    extension AccountDeletionGuideSheet {
        fileprivate enum Sample: CaseIterable {
            /// 月額で、自動更新がオン
            case monthlyAutoRenewing
            /// 年額で、自動更新がオン
            case yearlyAutoRenewing
            /// 商品を読めず、次の請求に価格が無い
            case priceUnavailable
            /// 解約の画面で解約して戻った
            case cancelled

            var guide: AccountDeletionGuide {
                let renewsOn = CalendarDay.sampleToday.advanced(by: 12)
                return switch self {
                case .monthlyAutoRenewing:
                    AccountDeletionGuide(
                        plan: .monthly, renewsOn: renewsOn, usableThrough: renewsOn,
                        displayPrice: "¥980", renewal: .autoRenewing)
                case .yearlyAutoRenewing:
                    AccountDeletionGuide(
                        plan: .yearly, renewsOn: renewsOn, usableThrough: renewsOn,
                        displayPrice: "¥8,800", renewal: .autoRenewing)
                case .priceUnavailable:
                    AccountDeletionGuide(
                        plan: .monthly, renewsOn: renewsOn, usableThrough: renewsOn,
                        displayPrice: nil, renewal: .autoRenewing)
                case .cancelled:
                    AccountDeletionGuide(
                        plan: .monthly, renewsOn: renewsOn, usableThrough: renewsOn,
                        displayPrice: "¥980", renewal: .cancelled)
                }
            }
        }
    }
#endif
