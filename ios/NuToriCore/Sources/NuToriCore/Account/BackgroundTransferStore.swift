public protocol BackgroundTransferStore: Sendable {
    /// 裏の送信だけを取り消す。送りかけのファイルは残し、次に開いたときに送り直せるようにする
    func cancelUploads() async

    /// 送りかけのファイルと、バックグラウンドの送信をすべて消す
    func cancelAndDeleteAll() async throws
}
