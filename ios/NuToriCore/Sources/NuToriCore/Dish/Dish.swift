public import Foundation

/// 料理。サーバーが推定の完了で作るか、使う人が足し、同期で届く。親の食事は ID で持つ（食事より先に届くことがある）
public struct Dish: Hashable, Sendable {
    public let id: UUID
    public let mealId: UUID
    public let name: String
    /// 足したばかりで、推定し直しが一度も当たっていない料理は nil
    public let quantity: Quantity?
    /// 食事の中の並び順。同じ値は ID の順で並べる
    public let positionInMeal: Int
    /// ヘルスケアの同期の版
    public let version: Int

    public init(
        id: UUID,
        mealId: UUID,
        name: String,
        quantity: Quantity?,
        positionInMeal: Int,
        version: Int
    ) {
        self.id = id
        self.mealId = mealId
        self.name = name
        self.quantity = quantity
        self.positionInMeal = positionInMeal
        self.version = version
    }

    /// 料理の量。単位は変えられない
    public struct Quantity: Hashable, Sendable {
        public let value: Double
        public let unit: String
        public let source: QuantitySource

        public init(value: Double, unit: String, source: QuantitySource) {
            self.value = value
            self.unit = unit
            self.source = source
        }
    }
}
