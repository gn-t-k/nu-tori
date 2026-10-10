/// サーバーが読み分けと返事の出来事から出す、送った文章の状態。サーバーだけが書き、同期で届く
public struct SentTextStatus: Hashable, Sendable {
    public let classification: Classification

    public init(classification: Classification) {
        self.classification = classification
    }

    /// 読み分けの今の結果
    public enum Classification: Hashable, Sendable {
        /// 読み分けを待っている
        case pending
        case meal
        case conversation
    }
}
