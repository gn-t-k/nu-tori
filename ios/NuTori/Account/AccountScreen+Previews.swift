#if DEBUG
    import SwiftUI

    #Preview("状態ごと", arguments: AccountScreen.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        NavigationStack {
            AccountScreen(
                sendsUsageData: sample.sendsUsageData,
                cameraAccess: sample.cameraAccess,
                deletion: sample.deletion,
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

            var sendsUsageData: Bool {
                switch self {
                case .notSendingUsageData: false
                case .sendingUsageData, .deleting, .deletionUnreachable, .deletionRetryLater,
                    .cameraNotPermitted, .cameraNotYetRequested:
                    true
                }
            }

            var cameraAccess: CameraAccess {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .deleting, .deletionUnreachable,
                    .deletionRetryLater:
                    .permitted
                case .cameraNotPermitted: .notPermitted
                case .cameraNotYetRequested: .notYetRequested
                }
            }

            var deletion: AccountScreen.Deletion {
                switch self {
                case .sendingUsageData, .notSendingUsageData, .cameraNotPermitted,
                    .cameraNotYetRequested:
                    .idle
                case .deleting: .deleting
                case .deletionUnreachable: .failed(.unreachable)
                case .deletionRetryLater: .failed(.retryLater)
                }
            }
        }
    }
#endif
