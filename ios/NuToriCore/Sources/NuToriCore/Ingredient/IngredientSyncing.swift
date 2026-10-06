public import Foundation
public import NuToriAPI

/// 材料の同期の形。端末も書く種類で、材料の量を直す書き込みを送り待ちから送る
public struct IngredientSyncing: SyncedRecordKind, RecordKindWrites {
    /// 送り待ちの種類の名前。変えると、送り待ちに残った材料が読めなくなる
    public static let kindName = RecordKindName.ingredient

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { self }

    /// 取りに行った変更のうち、当てる今の値（届いた順）と、消す材料の ID
    public struct Current: Sendable, Equatable {
        public let ingredients: [Ingredient]
        public let removedIngredientIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let pending = try PendingIngredientWrite(entry: entry)
        switch pending.write {
        case .update(let ingredientId, let quantity):
            return .updateIngredient(
                writeId: pending.writeId, ingredientId: ingredientId, quantity: quantity)
        }
    }

    /// 受け付けなかった直す書き込みは、サーバーに材料が無いときだけ、材料をキャッシュから外す。
    /// 推定し直しで置き換わった前の材料と、料理ごと消えていた材料は、削除の印を同期の働きが当てて外す。
    /// 画面に出す1行は、見え方のチケットで足す
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?
    ) throws -> KindRejection {
        let pending = try PendingIngredientWrite(entry: entry)
        switch (pending.write, current) {
        case (.update(let ingredientId, _), .absent):
            return KindRejection(
                rejectedWrite: nil,
                removingChanges: [.ingredientDeletion(ingredientId: ingredientId)])
        case (.update, .value), (.update, .deleted), (.update, nil):
            return KindRejection.none
        }
    }

    /// 材料の量を直したときの結果。送り待ちに足し、量の出どころを「直した」にした材料をキャッシュに当てる。
    /// 受け付ける範囲の外の量と、今と同じ量は直さず nil
    public func correcting(
        _ ingredient: Ingredient, to quantity: Double, enqueuing write: PendingIngredientWrite
    ) throws -> SyncBoxResult? {
        guard AcceptedRange.ingredientQuantity.bounds.contains(quantity),
            quantity != ingredient.quantity
        else { return nil }
        let corrected = ingredient.withQuantity(quantity, source: .corrected)
        return SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [
                KindChanges(kind: name, changes: [.ingredient(SyncedIngredient(corrected))])
            ]
        )
    }

    /// 取りに行った変更を、今の値の並びにする。料理より先に届いた材料も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> Current {
        var ingredients: [Ingredient] = []
        var removedIngredientIds: [UUID] = []
        for change in changes {
            if case .ingredient(let synced) = change {
                ingredients.append(Ingredient(synced))
            } else if case .ingredientDeletion(let ingredientId) = change {
                removedIngredientIds.append(ingredientId)
            }
        }
        return Current(ingredients: ingredients, removedIngredientIds: removedIngredientIds)
    }
}

extension Ingredient {
    /// 知らない栄養の項目（古い版の端末に、サーバーが足した項目）は読み飛ばす
    init(_ ingredient: SyncedIngredient) {
        self.init(
            id: ingredient.id,
            dishId: ingredient.dishId,
            name: ingredient.name,
            quantity: ingredient.quantity,
            quantitySource: QuantitySource(ingredient.quantitySource),
            unit: ingredient.unit,
            edibleGramsPerUnit: ingredient.edibleGramsPerUnit,
            positionInDish: ingredient.positionInDish,
            nutrientSource: NutrientSource(ingredient.nutrientSource),
            nutrients: Dictionary(
                uniqueKeysWithValues: ingredient.nutrients.compactMap { name, value in
                    Nutrient(rawValue: name).map { ($0, value) }
                })
        )
    }
}

extension QuantitySource {
    init(_ source: SyncedQuantitySource) {
        switch source {
        case .estimated: self = .estimated
        case .corrected: self = .corrected
        }
    }
}

extension SyncedQuantitySource {
    init(_ source: QuantitySource) {
        switch source {
        case .estimated: self = .estimated
        case .corrected: self = .corrected
        }
    }
}

extension SyncedIngredient {
    /// 栄養の項目の名前は、端末の項目の名前（サーバーと同じ書き方）にする
    init(_ ingredient: Ingredient) {
        self.init(
            id: ingredient.id,
            dishId: ingredient.dishId,
            name: ingredient.name,
            quantity: ingredient.quantity,
            quantitySource: SyncedQuantitySource(ingredient.quantitySource),
            unit: ingredient.unit,
            edibleGramsPerUnit: ingredient.edibleGramsPerUnit,
            positionInDish: ingredient.positionInDish,
            nutrientSource: SyncedIngredient.NutrientSource(ingredient.nutrientSource),
            nutrients: Dictionary(
                uniqueKeysWithValues: ingredient.nutrients.map { ($0.key.rawValue, $0.value) })
        )
    }
}

extension SyncedIngredient.NutrientSource {
    init(_ source: NutrientSource) {
        switch source {
        case .nutritionLabel(let basisGrams): self = .nutritionLabel(basisGrams: basisGrams)
        case .foodComposition(let foodNumber): self = .foodComposition(foodNumber: foodNumber)
        case .estimated: self = .estimated
        }
    }
}

extension NutrientSource {
    init(_ source: SyncedIngredient.NutrientSource) {
        switch source {
        case .nutritionLabel(let basisGrams): self = .nutritionLabel(basisGrams: basisGrams)
        case .foodComposition(let foodNumber): self = .foodComposition(foodNumber: foodNumber)
        case .estimated: self = .estimated
        }
    }
}
