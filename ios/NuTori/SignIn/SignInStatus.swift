import NuToriCore

enum SignInStatus: Equatable {
    case ready
    case signingIn
    case failed(AccountSession.SignInOutcome.FailureReason)
}
