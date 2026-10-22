/// その場で送る要求（同期の外の要求）が通らなかった理由。画面に出す1行を分ける
public enum RequestFailureReason: Sendable, Equatable {
    /// 電波が無いときと時間切れ
    case unreachable
    /// 回数の歯止め、サーバーの失敗、StoreKit の失敗
    case retryLater

    /// 要求が投げたエラーから
    init(_ error: any Error) {
        self = error.isUnreachableOrTimedOut ? .unreachable : .retryLater
    }
}
