/// アカウントを消せなかった理由。画面の文言はアプリのターゲットが持つ
public enum AccountDeletionFailure: Sendable {
    /// 電波が無いときと時間切れ
    case unreachable
    /// 回数の歯止め（429）とサーバーの失敗
    case retryLater
}
