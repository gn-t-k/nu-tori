public import Foundation

/// タイムラインに置く返事。届いた返事か、見守る要求で伸びている途中の返事。応える送った文章のすぐあとに並ぶ
public struct TimelineReply: Hashable, Sendable {
    /// 返事の ID。見守る要求で届いた ID と、届いた返事の ID は同じ
    public let id: UUID
    public let sentTextId: UUID
    public let body: String
    /// 見守る要求で伸びている途中か。届いた返事で置き換わると false
    public let isGrowing: Bool
    /// 返事の下に、返った順に縦に並べる食事の行
    public let referencedMeals: [ReferencedMeal]

    public init(
        id: UUID, sentTextId: UUID, body: String, isGrowing: Bool,
        referencedMeals: [ReferencedMeal]
    ) {
        self.id = id
        self.sentTextId = sentTextId
        self.body = body
        self.isGrowing = isGrowing
        self.referencedMeals = referencedMeals
    }

    /// 返事が指し示す食事の行
    public enum ReferencedMeal: Hashable, Sendable {
        /// 押すと食事の画面へ潜る行（写真の縮小・名前・時刻・›）
        case meal(MealCard)
        /// 指した食事が消えていた（キャッシュに無い）。押せない灰色の枠だけの行「削除した食事」
        case deleted(mealId: UUID)
    }
}
