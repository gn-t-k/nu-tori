/// サーバーが、このビルドを受け付けたか。応答を受け取るたびに知らせ、届かなかった要求では知らせない
public enum AppBuildVerdict: Sendable, Equatable {
    /// 426 でない応答
    case supported
    /// 426（最低バージョンより古い）
    case unsupported

    /// サーバーが最低バージョンより古いビルドを締め出すときの状態コード（426 Upgrade Required）
    public static let unsupportedStatusCode = 426

    public init(statusCode: Int) {
        self = statusCode == Self.unsupportedStatusCode ? .unsupported : .supported
    }
}
