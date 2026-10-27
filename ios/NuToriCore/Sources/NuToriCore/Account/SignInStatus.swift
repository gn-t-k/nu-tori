/// サインインの画面のボタンの状態
public enum SignInStatus: Equatable, Sendable {
    case ready
    case signingIn
    case failed(AccountSession.SignInOutcome.FailureReason)
}
