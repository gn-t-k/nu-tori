/// サーバーが読み分けと返事の出来事から出す、送った文章の状態。サーバーだけが書き、同期で届く
public struct SentTextStatus: Hashable, Sendable {
    public let classification: Classification
    public let reply: Reply

    public init(classification: Classification, reply: Reply) {
        self.classification = classification
        self.reply = reply
    }

    /// 読み分けの今の結果
    public enum Classification: Hashable, Sendable {
        /// 読み分けを待っている
        case pending
        case meal
        case conversation
    }

    /// 応答の状態
    public enum Reply: Hashable, Sendable {
        /// 返事の依頼が無い（読み分けを待っている・食事と読み分けた）
        case notRequested
        /// 応答待ち（返事を作るのを待っている・作っている・やり直しを待っている）
        case awaiting
        case replied
        /// その日の回数切れ
        case halted
        /// 作れなかった
        case failed(FailureReason)
    }

    /// 作れなかった理由。理由ごとに1行の文言が変わる
    public enum FailureReason: Hashable, Sendable {
        /// やり直しを使い切った
        case retriesExhausted
        /// 提供元が受け付けなかった（400）
        case badRequest
    }
}
