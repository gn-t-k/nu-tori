/// エラーの報告の送り先（Sentry）
public protocol ErrorReportingSession: Sendable {
    func identify(accountId: String) async
    /// 原因のエラーが無い失敗（応答の状態コードで決めたもの、開くときに対処したもの）は、`cause` を nil にする
    func report(_ failure: HandledFailure, cause: FailureCause?) async
    func clearUser() async
}

extension ErrorReportingSession {
    /// 想定した結果の失敗（`HandledFailure.reported` が外すもの）でなければ、原因をつけて送る
    public func report(_ error: any Error, as area: HandledFailure) async {
        guard let failure = HandledFailure.reported(error, as: area) else { return }
        await report(failure, cause: FailureCause(error))
    }
}
