/// サーバーが、このビルドを受け付けたか。応答を受け取るたびに知らせ、届かなかった要求では知らせない
public enum AppBuildVerdict: Sendable, Equatable {
    /// 426 でない応答
    case supported
    /// 426（最低バージョンより古い）
    case unsupported
}
