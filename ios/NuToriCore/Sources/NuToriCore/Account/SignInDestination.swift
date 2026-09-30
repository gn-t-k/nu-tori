public enum SignInDestination: Sendable, Equatable {
    case signIn(Prompt)
    /// 初回の取得を終えていない
    case loadingTimeline
    case timeline

    public enum Prompt: Sendable, Equatable {
        /// 説明のひとことの版。初めて開いたときと、この端末でアカウントを削除したあと
        case introduction
        /// 説明のひとことの代わりに、サインインし直しの1行を置く版
        case signInAgain(hasPendingWrites: Bool)
    }
}
