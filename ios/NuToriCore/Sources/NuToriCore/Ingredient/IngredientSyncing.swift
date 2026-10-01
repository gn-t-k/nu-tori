public import Foundation
public import NuToriAPI

/// 材料の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct IngredientSyncing: SyncedRecordKind {
    public static let kindName = RecordKindName.ingredient

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    /// 取りに行った変更のうち、当てる今の値（届いた順）と、消す材料の ID
    public struct Current: Sendable, Equatable {
        public let ingredients: [Ingredient]
        public let removedIngredientIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        switch change {
        case .ingredient, .ingredientDeletion: true
        case .weightRecord, .weightRecordDeletion, .accountSettings, .dish, .dishDeletion, .meal,
            .mealDeletion, .mealEstimationStatus, .mealEstimationStatusDeletion, .unknown:
            false
        }
    }

    /// 取りに行った変更を、今の値の並びにする。料理より先に届いた材料も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> Current {
        var ingredients: [Ingredient] = []
        var removedIngredientIds: [UUID] = []
        for change in changes {
            switch change {
            case .ingredient(let synced): ingredients.append(Ingredient(synced))
            case .ingredientDeletion(let ingredientId): removedIngredientIds.append(ingredientId)
            case .weightRecord, .weightRecordDeletion, .accountSettings, .dish, .dishDeletion,
                .meal, .mealDeletion, .mealEstimationStatus, .mealEstimationStatusDeletion,
                .unknown:
                break
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

extension NutrientSource {
    init(_ source: SyncedIngredient.NutrientSource) {
        switch source {
        case .nutritionLabel(let basisGrams): self = .nutritionLabel(basisGrams: basisGrams)
        case .foodComposition(let foodNumber): self = .foodComposition(foodNumber: foodNumber)
        case .estimated: self = .estimated
        }
    }
}
