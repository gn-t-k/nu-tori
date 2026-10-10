import NuToriAPI

extension SentTextStatus {
    /// キャッシュに文字列で持つ値。サーバーの値（`SyncedSentTextStatus`）と同じ文字列にし、対応はそちらの1か所に置く
    public var storedValue:
        (classification: String, replyStatus: String, replyFailureReason: String?)
    {
        let reply = SyncedSentTextStatus.Reply(reply).serverValue
        return (
            SyncedSentTextStatus.Classification(classification).rawValue, reply.status,
            reply.failureReason
        )
    }

    /// キャッシュの値から読む。知らない値は nil
    public init?(storedClassification: String, replyStatus: String, replyFailureReason: String?) {
        guard
            let classification = SyncedSentTextStatus.Classification(
                rawValue: storedClassification),
            let reply = SyncedSentTextStatus.Reply(
                serverStatus: replyStatus, failureReason: replyFailureReason)
        else {
            return nil
        }
        self.init(classification: Classification(classification), reply: Reply(reply))
    }
}
