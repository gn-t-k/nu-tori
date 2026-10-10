public import Foundation

/// 送った文章の状態。サーバーだけが書く。記録の ID は送った文章の ID
public struct SyncedSentTextStatus: Sendable, Equatable {
    public let sentTextId: UUID
    public let classification: Classification

    public init(sentTextId: UUID, classification: Classification) {
        self.sentTextId = sentTextId
        self.classification = classification
    }

    /// 読み分けの今の結果。サーバーの `classification` の値
    public enum Classification: String, Sendable, Equatable {
        case pending
        case meal
        case conversation
    }
}
