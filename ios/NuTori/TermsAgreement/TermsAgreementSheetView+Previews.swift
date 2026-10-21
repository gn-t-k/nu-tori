#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: TermsAgreementSheetView.Sample.allCases) { sample in
        TermsAgreementSheetView(progress: sample.progress) { .agreed }
    }

    extension TermsAgreementSheetView {
        fileprivate enum Sample: CaseIterable {
            /// 出したところ
            case ready
            /// 同意を送って、応答を待っている
            case agreeing
            /// インターネットにつながらず、送れなかった
            case failedUnreachable
            /// ほかの理由で、受け付けられなかった
            case failedRetryLater

            var progress: TermsAgreementSheetView.Progress {
                switch self {
                case .ready: .ready
                case .agreeing: .agreeing
                case .failedUnreachable: .failed(.unreachable)
                case .failedRetryLater: .failed(.retryLater)
                }
            }
        }
    }
#endif
