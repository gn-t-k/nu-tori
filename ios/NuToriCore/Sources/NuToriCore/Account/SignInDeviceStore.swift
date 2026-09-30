/// キーチェーンの外の、アプリを消すと消える場所に置く、サインインの状態
public protocol SignInDeviceStore: Sendable {
    /// 入れ直したあとの最初の起動かを見分けるための印。キーチェーンはアプリを消しても残る
    func hasOpenedBefore() async throws -> Bool
    func markOpened() async throws

    func signedInAccount() async throws -> SignedInAccount?
    func save(_ account: SignedInAccount) async throws

    func hasSignInAgainMark() async throws -> Bool
    func setSignInAgainMark() async throws
    func clearSignInAgainMark() async throws

    /// アカウント ID と Apple の識別子、端末 ID、サインインし直しの印を消す。開いた印は消さない
    func eraseAccountBoundState() async throws
}
