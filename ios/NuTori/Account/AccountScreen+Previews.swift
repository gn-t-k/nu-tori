#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: AccountScreen.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        NavigationStack {
            AccountScreen(
                subscription: AccountScreen.SubscriptionSample.freeTrial.row,
                openPaywall: {},
                sendsUsageData: sample.sendsUsageData,
                cameraAccess: sample.cameraAccess,
                notificationPermission: sample.notificationPermission,
                deletion: sample.deletion,
                signOutStep: sample.signOutStep,
                appVersion: "1.0",
                appBuild: 53,
                actions: .noop,
                onClose: {}
            )
        }
    }

    // サブスクリプションの行の形は、ほかの状態と組み合わせずに並べる
    #Preview("サブスクリプションの行", arguments: AccountScreen.SubscriptionSample.allCases) { sample in
        NavigationStack {
            AccountScreen(
                subscription: sample.row,
                openPaywall: {},
                sendsUsageData: true,
                cameraAccess: .permitted,
                notificationPermission: .permitted,
                deletion: .idle,
                signOutStep: .idle,
                appVersion: "1.0",
                appBuild: 53,
                actions: .noop,
                onClose: {}
            )
        }
    }

    extension AccountScreen {
        fileprivate enum SubscriptionSample: CaseIterable {
            case freeTrial
            case subscribed
            /// 自動更新をオフにした
            case cancelled
            case expired
            case testUser
            /// サブスクリプションの状態がまだ届いていない
            case notArrived

            var row: AccountSubscriptionRow? {
                let tokyo = TimeZone(identifier: "Asia/Tokyo")!
                let periodEndsAt = CalendarDay.sampleToday.advanced(by: 30).noon(in: tokyo)
                let subscribed = SubscriptionStanding.subscribed(
                    plan: .monthly, periodEndsAt: periodEndsAt, endsAt: periodEndsAt)
                return switch self {
                case .freeTrial:
                    AccountSubscriptionRow(
                        standing: .freeTrial(
                            lastDay: CalendarDay.sampleToday.advanced(by: 9), remainingDays: 10),
                        autoRenewal: .unknown, timeZone: tokyo)
                case .subscribed:
                    AccountSubscriptionRow(standing: subscribed, autoRenewal: .on, timeZone: tokyo)
                case .cancelled:
                    AccountSubscriptionRow(standing: subscribed, autoRenewal: .off, timeZone: tokyo)
                case .expired:
                    AccountSubscriptionRow(
                        standing: .expired, autoRenewal: .unknown, timeZone: tokyo)
                case .testUser:
                    AccountSubscriptionRow(
                        standing: .testUser, autoRenewal: .unknown, timeZone: tokyo)
                case .notArrived:
                    nil
                }
            }
        }

        fileprivate enum Sample: CaseIterable {
            /// 利用状況を送る
            case sendingUsageData
            /// 利用状況を送らない
            case notSendingUsageData
            /// アカウントを消している途中
            case deleting
            /// インターネットにつながらず、消せなかった
            case deletionUnreachable
            /// サーバーが断り、消せなかった
            case deletionRetryLater
            /// サインアウトの前に、送り待ちがあるかを読んでいる
            case checkingPendingWrites
            /// 送り待ちがあり、サインアウトを確かめている
            case signOutConfirming
            /// サインインの画面に替わるのを待っている
            case signingOut
            /// カメラを許可していない
            case cameraNotPermitted
            /// まだ一度も撮っておらず、カメラの許可を求めていない
            case cameraNotYetRequested
            /// 通知を許可していない
            case notificationsNotPermitted
            /// まだ一度も体重を記録しておらず、通知の許可を求めていない
            case notificationsNotYetRequested
            /// 通知の許可を読んでいる途中
            case notificationsReading

            var sendsUsageData: Bool {
                switch self {
                case .notSendingUsageData: false
                case .sendingUsageData, .deleting, .deletionUnreachable, .deletionRetryLater,
                    .checkingPendingWrites, .signOutConfirming, .signingOut, .cameraNotPermitted,
                    .cameraNotYetRequested,
                    .notificationsNotPermitted,
                    .notificationsNotYetRequested, .notificationsReading:
                    true
                }
            }

            var cameraAccess: CameraAccess {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .deleting, .deletionUnreachable,
                    .deletionRetryLater, .checkingPendingWrites, .signOutConfirming, .signingOut,
                    .notificationsNotPermitted, .notificationsNotYetRequested,
                    .notificationsReading:
                    .permitted
                case .cameraNotPermitted: .notPermitted
                case .cameraNotYetRequested: .notYetRequested
                }
            }

            var notificationPermission: NotificationPermission? {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .deleting, .deletionUnreachable,
                    .deletionRetryLater, .checkingPendingWrites, .signOutConfirming, .signingOut,
                    .cameraNotPermitted,
                    .cameraNotYetRequested:
                    .permitted
                case .notificationsNotPermitted: .notPermitted
                case .notificationsNotYetRequested: .notYetRequested
                case .notificationsReading: nil
                }
            }

            var deletion: AccountScreen.Deletion {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .cameraNotPermitted,
                    .cameraNotYetRequested, .notificationsNotPermitted,
                    .notificationsNotYetRequested,
                    .notificationsReading, .checkingPendingWrites, .signOutConfirming, .signingOut:
                    .idle
                case .deleting: .deleting
                case .deletionUnreachable: .failed(.unreachable)
                case .deletionRetryLater: .failed(.retryLater)
                }
            }

            var signOutStep: AccountScreen.SignOutStep {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .deleting, .deletionUnreachable,
                    .deletionRetryLater, .cameraNotPermitted, .cameraNotYetRequested,
                    .notificationsNotPermitted, .notificationsNotYetRequested,
                    .notificationsReading:
                    .idle
                case .checkingPendingWrites: .checkingPendingWrites
                case .signOutConfirming: .confirming
                case .signingOut: .signingOut
                }
            }
        }
    }
#endif
