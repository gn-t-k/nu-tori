public import Foundation

/// 料理。サーバーが推定の完了と料理を足す書き込みで作る。親の食事は ID で持つ
public struct SyncedDish: Sendable, Equatable {
    public let id: UUID
    public let mealId: UUID
    public let name: String
    /// 足したばかりで、推定し直しが一度も当たっていない料理は nil
    public let quantity: Quantity?
    /// 食事の中の並び順。同じ値は ID の順で並べる
    public let positionInMeal: Int
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

    /// 料理の量。量と単位と出どころは、そろって届くか、そろって無い
    public struct Quantity: Sendable, Equatable {
        public let value: Double
        public let unit: String
        public let source: SyncedQuantitySource

        public init(value: Double, unit: String, source: SyncedQuantitySource) {
            self.value = value
            self.unit = unit
            self.source = source
        }
    }
}
