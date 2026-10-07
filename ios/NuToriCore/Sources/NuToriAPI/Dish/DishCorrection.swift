public import Foundation

/// 料理を直す書き込みの中身。量を直すときは名前と量を運び、サーバーが今の値と違う分だけを修正として足す
public struct DishCorrection: Sendable, Equatable {
    public let id: UUID
    public let name: String
    /// 名前だけを直すときは nil
    public let quantity: Quantity?

    public init(id: UUID, name: String, quantity: Quantity?) {
        self.id = id
        self.name = name
        self.quantity = quantity
    }

    public struct Quantity: Sendable, Equatable {
        public let value: Double
        /// 量を直したときに、端末が今の材料の量を同じ割合で変えた量。サーバーは割合を計算し直さない
        public let proportionedIngredients: [ProportionedIngredient]

        public init(value: Double, proportionedIngredients: [ProportionedIngredient]) {
            self.value = value
            self.proportionedIngredients = proportionedIngredients
        }
    }

    public struct ProportionedIngredient: Sendable, Equatable {
        public let ingredientId: UUID
        public let quantity: Double

        public init(ingredientId: UUID, quantity: Double) {
            self.ingredientId = ingredientId
            self.quantity = quantity
        }
    }
}
