public import Foundation
public import NuToriAPI

/// 料理の書き込み。送り待ちの置き場には、料理の種類の名前と、この中身の JSON で入る
public enum DishWrite: PendingWriteBody {
    /// 料理を足す。名前だけで作り、量と材料はサーバーの推定し直しで入る
    case create(NewDish)
    /// 名前と量を両方運ぶ。量の無い料理の名前を直すときは、量と比例の材料を省く
    case update(DishCorrection)
    case delete(dishId: UUID)

    public static var kindName: RecordKindName { DishSyncing.kindName }

    public var stored: Stored { Stored(self) }

    public init?(stored: Stored) {
        self = stored.write()
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    public enum Stored: Codable {
        case create(StoredNewDish)
        case update(StoredCorrection)
        case delete(dishId: UUID)

        init(_ write: DishWrite) {
            switch write {
            case .create(let dish): self = .create(StoredNewDish(dish))
            case .update(let correction): self = .update(StoredCorrection(correction))
            case .delete(let dishId): self = .delete(dishId: dishId)
            }
        }

        func write() -> DishWrite {
            switch self {
            case .create(let stored): .create(stored.newDish())
            case .update(let stored): .update(stored.correction())
            case .delete(let dishId): .delete(dishId: dishId)
            }
        }
    }

    public struct StoredNewDish: Codable {
        let id: UUID
        let mealId: UUID
        let name: String
        let positionInMeal: Int

        init(_ dish: NewDish) {
            id = dish.id
            mealId = dish.mealId
            name = dish.name
            positionInMeal = dish.positionInMeal
        }

        func newDish() -> NewDish {
            NewDish(id: id, mealId: mealId, name: name, positionInMeal: positionInMeal)
        }
    }

    public struct StoredCorrection: Codable {
        let id: UUID
        let name: String
        let quantity: StoredQuantity?

        init(_ correction: DishCorrection) {
            id = correction.id
            name = correction.name
            quantity = correction.quantity.map(StoredQuantity.init)
        }

        func correction() -> DishCorrection {
            DishCorrection(id: id, name: name, quantity: quantity?.quantity())
        }
    }

    public struct StoredQuantity: Codable {
        let value: Double
        let proportionedIngredients: [StoredProportionedIngredient]

        init(_ quantity: DishCorrection.Quantity) {
            value = quantity.value
            proportionedIngredients = quantity.proportionedIngredients.map {
                StoredProportionedIngredient(ingredientId: $0.ingredientId, quantity: $0.quantity)
            }
        }

        func quantity() -> DishCorrection.Quantity {
            DishCorrection.Quantity(
                value: value,
                proportionedIngredients: proportionedIngredients.map {
                    DishCorrection.ProportionedIngredient(
                        ingredientId: $0.ingredientId, quantity: $0.quantity)
                })
        }
    }

    public struct StoredProportionedIngredient: Codable {
        let ingredientId: UUID
        let quantity: Double
    }
}

/// 料理の送り待ち
public typealias PendingDishWrite = Pending<DishWrite>
