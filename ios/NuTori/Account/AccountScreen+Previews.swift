#if DEBUG
    import SwiftUI

    #Preview("状態ごと", arguments: AccountScreen.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        NavigationStack {
            AccountScreen(
                sendsUsageData: sample.sendsUsageData,
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

            var sendsUsageData: Bool {
                switch self {
                case .notSendingUsageData: false
                case .sendingUsageData, .deleting, .deletionUnreachable, .deletionRetryLater: true
                }
            }

            var deletion: AccountScreen.Deletion {
                switch self {
                case .sendingUsageData, .notSendingUsageData: .idle
                case .deleting: .deleting
                case .deletionUnreachable: .failed(.unreachable)
                case .deletionRetryLater: .failed(.retryLater)
                }
            }
        }
    }
#endif
