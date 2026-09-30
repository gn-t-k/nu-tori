public protocol BackgroundTransferStore: Sendable {
    /// 送りかけのファイルと、バックグラウンドの送信をすべて消す
    func cancelAndDeleteAll() async throws
}
