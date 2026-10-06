public import Foundation

/// 料理を足す書き込みの中身。名前だけで作り、量と材料はサーバーの推定し直しで入る
public struct NewDish: Sendable, Equatable {
    /// 端末が振る UUID v4
    public let id: UUID
    public let mealId: UUID
    public let name: String
    /// 端末のキャッシュの、その食事の料理の最後の次の値。一意にせず、同じなら ID の順で並べる
    public let positionInMeal: Int

    public init(id: UUID, mealId: UUID, name: String, positionInMeal: Int) {
        self.id = id
        self.mealId = mealId
        self.name = name
        self.positionInMeal = positionInMeal
    }
}
