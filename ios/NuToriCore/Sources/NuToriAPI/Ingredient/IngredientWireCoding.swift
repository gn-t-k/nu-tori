import Foundation

struct IngredientWireCoding: RecordKindWriteWireCoding {
    let kind = Components.Schemas.RecordKindName.ingredient

    var writes: (any RecordKindWriteWireCoding)? { self }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.IngredientPayload.self).syncedIngredient)
                .map { .ingredient($0) }
        case .deletion: UUID(uuidString: recordId).map { .ingredientDeletion(ingredientId: $0) }
        case .absence: nil
        }
    }

    func wire(of write: SyncWrite) -> SyncWrite.Wire? {
        guard case .updateIngredient(let writeId, let ingredientId, let quantity) = write else {
            return nil
        }
        return .init(
            recordId: ingredientId,
            body: .updateIngredient(
                .init(
                    id: writeId.canonicalString,
                    _type: .updateIngredient,
                    ingredientId: ingredientId.canonicalString,
                    quantity: quantity
                )
            ))
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .ingredient(let ingredient) = change {
                return .value(id: ingredient.id, record: SyncChange.IngredientPayload(ingredient))
            }
            if case .ingredientDeletion(let ingredientId) = change {
                return .deletion(id: ingredientId)
            }
            return nil
        }

        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite? {
            guard case .updateIngredient(let write) = wire else { return nil }
            return .updateIngredient(
                writeId: try uuid(write.id),
                ingredientId: try uuid(write.ingredientId),
                quantity: write.quantity)
        }
    #endif
}

extension SyncChange {
    /// 知らない出どころ（栄養と量）と、読めない ID は nil にする。知らない栄養の項目の名前は、そのまま持つ
    struct IngredientPayload: Decodable {
        let id: String
        let dishId: String
        let name: String
        let quantity: Double
        let quantitySource: String
        let unit: String
        let edibleGramsPerUnit: Double
        let positionInDish: Int
        let nutrientSource: NutrientSourcePayload
        let nutrients: [String: Double]

        struct NutrientSourcePayload: Decodable {
            let type: String
            let labelBasisGrams: Double?
            let foodNumber: String?

            var syncedSource: SyncedIngredient.NutrientSource? {
                switch type {
                case "nutrition_label":
                    labelBasisGrams.map { .nutritionLabel(basisGrams: $0) }
                case "food_composition":
                    foodNumber.map { .foodComposition(foodNumber: $0) }
                case "estimated":
                    .estimated
                default:
                    nil
                }
            }
        }

        var syncedIngredient: SyncedIngredient? {
            guard let id = UUID(uuidString: id), let dishId = UUID(uuidString: dishId),
                let source = nutrientSource.syncedSource,
                let quantitySource = SyncedQuantitySource(rawValue: quantitySource)
            else {
                return nil
            }
            return SyncedIngredient(
                id: id, dishId: dishId, name: name, quantity: quantity,
                quantitySource: quantitySource, unit: unit,
                edibleGramsPerUnit: edibleGramsPerUnit, positionInDish: positionInDish,
                nutrientSource: source, nutrients: nutrients)
        }
    }
}

#if DEBUG
    extension SyncChange.IngredientPayload: Encodable {
        fileprivate init(_ ingredient: SyncedIngredient) {
            let source: NutrientSourcePayload =
                switch ingredient.nutrientSource {
                case .nutritionLabel(let basisGrams):
                    .init(type: "nutrition_label", labelBasisGrams: basisGrams, foodNumber: nil)
                case .foodComposition(let foodNumber):
                    .init(type: "food_composition", labelBasisGrams: nil, foodNumber: foodNumber)
                case .estimated:
                    .init(type: "estimated", labelBasisGrams: nil, foodNumber: nil)
                }
            self.init(
                id: ingredient.id.canonicalString, dishId: ingredient.dishId.canonicalString,
                name: ingredient.name, quantity: ingredient.quantity,
                quantitySource: ingredient.quantitySource.rawValue, unit: ingredient.unit,
                edibleGramsPerUnit: ingredient.edibleGramsPerUnit,
                positionInDish: ingredient.positionInDish, nutrientSource: source,
                nutrients: ingredient.nutrients)
        }
    }
    extension SyncChange.IngredientPayload.NutrientSourcePayload: Encodable {}
#endif
