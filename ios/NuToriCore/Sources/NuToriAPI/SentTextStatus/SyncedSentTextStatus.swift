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

        /// 知らない応答の状態と作れなかった理由は nil
        public init?(serverStatus: String, failureReason: String?) {
            switch serverStatus {
            case "none": self = .notRequested
            case "awaiting": self = .awaiting
            case "replied": self = .replied
            case "halted": self = .halted
            case "failed":
                guard let reason = failureReason.flatMap(FailureReason.init(rawValue:)) else {
                    return nil
                }
                self = .failed(reason)
            default: return nil
            }
        }

        public var serverValue: (status: String, failureReason: String?) {
            switch self {
            case .notRequested: ("none", nil)
            case .awaiting: ("awaiting", nil)
            case .replied: ("replied", nil)
            case .halted: ("halted", nil)
            case .failed(let reason): ("failed", reason.rawValue)
            }
        }
    }

    /// 作れなかった理由。サーバーの `replyFailureReason` の値
    public enum FailureReason: String, Sendable, Equatable {
        case retriesExhausted = "retries_exhausted"
        case badRequest = "bad_request"
    }
}
