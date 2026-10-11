public import Foundation

/// タイムラインに置く返事。届いた返事か、見守る要求で伸びている途中の返事。応える送った文章のすぐあとに並ぶ
public struct TimelineReply: Hashable, Sendable {
    /// 返事の ID。見守る要求で届いた ID と、届いた返事の ID は同じ
    public let id: UUID
    public let sentTextId: UUID
    public let body: String
    /// 見守る要求で伸びている途中か。届いた返事で置き換わると false
    public let isGrowing: Bool
    /// 返事の下に、返った順に縦に並べる食事の行。押すと食事の画面へ潜る。指した食事が消えていたら並べない
    public let referencedMeals: [MealCard]

    public init(
        id: UUID, sentTextId: UUID, body: String, isGrowing: Bool,
        referencedMeals: [MealCard]
    ) {
        self.id = id
        self.sentTextId = sentTextId
        self.body = body
        self.isGrowing = isGrowing
        self.referencedMeals = referencedMeals
    }
}
