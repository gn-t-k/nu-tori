#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: AccountScreen.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        NavigationStack {
            AccountScreen(
                sendsUsageData: sample.sendsUsageData,
                cameraAccess: sample.cameraAccess,
                notificationPermission: sample.notificationPermission,
                deletion: sample.deletion,
                appVersion: "1.0",
                appBuild: 53,
                actions: .noop,
                onClose: {}
            )
        }
    }

    extension AccountScreen {
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
                    .cameraNotPermitted, .cameraNotYetRequested, .notificationsNotPermitted,
                    .notificationsNotYetRequested, .notificationsReading:
                    true
                }
            }

            var cameraAccess: CameraAccess {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .deleting, .deletionUnreachable,
                    .deletionRetryLater, .notificationsNotPermitted, .notificationsNotYetRequested,
                    .notificationsReading:
                    .permitted
                case .cameraNotPermitted: .notPermitted
                case .cameraNotYetRequested: .notYetRequested
                }
            }

            var notificationPermission: NotificationPermission? {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .deleting, .deletionUnreachable,
                    .deletionRetryLater, .cameraNotPermitted, .cameraNotYetRequested:
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
                    .notificationsReading:
                    .idle
                case .deleting: .deleting
                case .deletionUnreachable: .failed(.unreachable)
                case .deletionRetryLater: .failed(.retryLater)
                }
            }
        }
    }
#endif
