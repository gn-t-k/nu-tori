public import Foundation

/// 送った文章の状態。サーバーだけが書く。記録の ID は送った文章の ID
public struct SyncedSentTextStatus: Sendable, Equatable {
    public let sentTextId: UUID
    public let classification: Classification
    public let reply: Reply

    public init(sentTextId: UUID, classification: Classification, reply: Reply) {
        self.sentTextId = sentTextId
        self.classification = classification
        self.reply = reply
    }

    /// 読み分けの今の結果。サーバーの `classification` の値
    public enum Classification: String, Sendable, Equatable {
        case pending
        case meal
        case conversation
    }

    /// 応答の状態。サーバーの `replyStatus` と、作れなかったときの `replyFailureReason` の値
    public enum Reply: Sendable, Equatable {
        /// サーバーの none
        case notRequested
        case awaiting
        case replied
        case halted
        case failed(FailureReason)
    }

    /// 作れなかった理由。サーバーの `replyFailureReason` の値
    public enum FailureReason: String, Sendable, Equatable {
        case retriesExhausted = "retries_exhausted"
        case badRequest = "bad_request"
    }
}
