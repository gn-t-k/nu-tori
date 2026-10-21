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

    /// 応答の状態。サーバーの `replyStatus` と、作れなかったときの `replyFailureReason`、止めたときの `replyHaltReason` の値
    public enum Reply: Sendable, Equatable {
        /// サーバーの none
        case notRequested
        case awaiting
        case replied
        case halted(HaltReason)
        case failed(FailureReason)

        /// 知らない応答の状態と、作れなかった理由・止めた理由は nil。
        /// 止めた理由の無い止めは、理由を足す前のサーバーの回数切れとして読む
        public init?(serverStatus: String, failureReason: String?, haltReason: String?) {
            switch serverStatus {
            case "none": self = .notRequested
            case "awaiting": self = .awaiting
            case "replied": self = .replied
            case "halted":
                guard let reason = HaltReason(serverValue: haltReason) else { return nil }
                self = .halted(reason)
            case "failed":
                guard let reason = failureReason.flatMap(FailureReason.init(rawValue:)) else {
                    return nil
                }
                self = .failed(reason)
            // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
            default: return nil
            }
        }

        public var serverValue: (status: String, failureReason: String?, haltReason: String?) {
            switch self {
            case .notRequested: ("none", nil, nil)
            case .awaiting: ("awaiting", nil, nil)
            case .replied: ("replied", nil, nil)
            case .halted(let reason): ("halted", nil, reason.rawValue)
            case .failed(let reason): ("failed", reason.rawValue, nil)
            }
        }
    }

    /// 止めた理由。サーバーの `replyHaltReason` の値。買っても再開しない
    public enum HaltReason: String, Sendable, Equatable {
        /// その日の回数切れ
        case dailyLimit = "daily_limit"
        /// サブスクリプション切れ
        case subscriptionExpired = "subscription_expired"

        /// 無ければ回数切れ（理由を足す前のサーバー）。知らない値は nil
        init?(serverValue: String?) {
            guard let serverValue else {
                self = .dailyLimit
                return
            }
            self.init(rawValue: serverValue)
        }
    }

    /// 作れなかった理由。サーバーの `replyFailureReason` の値
    public enum FailureReason: String, Sendable, Equatable {
        case retriesExhausted = "retries_exhausted"
        case badRequest = "bad_request"
    }
}
