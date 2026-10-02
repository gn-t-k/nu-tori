/// アプリのビルド番号と、サーバーがそのビルドを受け付けたかを知らせる先。
/// すべての要求にビルド番号を付け、応答を受け取るたびに状態コードから受け付けたかを知らせる
public struct AppBuildGate: Sendable {
    /// アプリのビルド番号（`CFBundleVersion`）。すべての要求に `X-App-Build` で付ける
    public let build: Int
    /// 応答を受け取るたびに、サーバーがこのビルドを受け付けたかを知らせる先。届かなかった要求では知らせない
    public let verdict: @Sendable (AppBuildVerdict) async -> Void

    public init(build: Int, verdict: @escaping @Sendable (AppBuildVerdict) async -> Void) {
        self.build = build
        self.verdict = verdict
    }

    /// 受け取った応答の状態コードから、受け付けたかを知らせ、その結果を返す
    @discardableResult
    func receive(statusCode: Int) async -> AppBuildVerdict {
        let received = AppBuildVerdict(statusCode: statusCode)
        await verdict(received)
        return received
    }
}
