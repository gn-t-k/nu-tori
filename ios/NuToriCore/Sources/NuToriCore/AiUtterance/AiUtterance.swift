public import Foundation

/// 返事。サーバーだけが書き、消えない。送った文章より先に届くことがあるので、送った文章の ID を値で持つ
public struct AiUtterance: Hashable, Sendable {
    public let id: UUID
    public let body: String
    /// 応える送った文章。時刻とタイムゾーンはこの文章のものを使う
    public let sentTextId: UUID
    /// 指し示す食事。並びが返事の中の並びで、食事が消えても残る
    public let mealIds: [UUID]

    public init(id: UUID, body: String, sentTextId: UUID, mealIds: [UUID]) {
        self.id = id
        self.body = body
        self.sentTextId = sentTextId
        self.mealIds = mealIds
    }
}
