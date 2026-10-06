public import Foundation

/// 材料の書き込み。送り待ちの置き場には、材料の種類の名前と、この中身の JSON で入る
public enum IngredientWrite: PendingWriteBody {
    /// 量を直す。名前は直せない
    case update(ingredientId: UUID, quantity: Double)

    public static var kindName: RecordKindName { IngredientSyncing.kindName }

    public var stored: Stored { Stored(self) }

    public init?(stored: Stored) {
        self = stored.write()
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    public enum Stored: Codable {
        case update(ingredientId: UUID, quantity: Double)

        init(_ write: IngredientWrite) {
            switch write {
            case .update(let ingredientId, let quantity):
                self = .update(ingredientId: ingredientId, quantity: quantity)
            }
        }

        func write() -> IngredientWrite {
            switch self {
            case .update(let ingredientId, let quantity):
                .update(ingredientId: ingredientId, quantity: quantity)
            }
        }
    }
}

/// 材料の送り待ち
public typealias PendingIngredientWrite = Pending<IngredientWrite>
