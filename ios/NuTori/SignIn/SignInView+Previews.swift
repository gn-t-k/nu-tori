#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: SignInView.Sample.allCases) { sample in
        SignInView(prompt: sample.prompt, status: sample.status) { _ in }
    }

    extension SignInView {
        fileprivate enum Sample: CaseIterable {
            /// 初めて開いた
            case introduction
            /// セッションが切れた
            case signInAgain
            /// セッションが切れ、まだ送っていない記録がある
            case signInAgainWithPendingWrites
            /// サインインの途中
            case signingIn
            /// インターネットにつながらず、サインインできなかった
            case failedUnreachable
            /// ほかの理由で、サインインできなかった
            case failedOther

            var prompt: SignInDestination.Prompt {
                switch self {
                case .introduction, .signingIn, .failedUnreachable, .failedOther: .introduction
                case .signInAgain: .signInAgain(hasPendingWrites: false)
                case .signInAgainWithPendingWrites: .signInAgain(hasPendingWrites: true)
                }
            }

            var status: SignInStatus {
                switch self {
                case .introduction, .signInAgain, .signInAgainWithPendingWrites: .ready
                case .signingIn: .signingIn
                case .failedUnreachable: .failed(.unreachable)
                case .failedOther: .failed(.other)
                }
            }
        }
    }
#endif
