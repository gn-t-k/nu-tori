public import Foundation

/// 料理。サーバーが推定の完了で作り、同期で届く。親の食事は ID で持つ（食事より先に届くことがある）
public struct Dish: Hashable, Sendable {
    public let id: UUID
    public let mealId: UUID
    public let name: String
    public let quantity: Double
    public let unit: String
    /// 食事の中の並び順。同じ値は ID の順で並べる
    public let positionInMeal: Int
    /// ヘルスケアの同期の版
    public let version: Int

    public init(
        id: UUID,
        mealId: UUID,
        name: String,
        quantity: Double,
        unit: String,
        positionInMeal: Int,
        version: Int
    ) {
        self.id = id
        self.mealId = mealId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.positionInMeal = positionInMeal
        self.version = version
    }
}
