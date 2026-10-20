import Foundation

struct DishWireCoding: RecordKindWriteWireCoding {
    let kind = Components.Schemas.RecordKindName.dish

    var writes: (any RecordKindWriteWireCoding)? { self }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.DishPayload.self).syncedDish).map { .dish($0) }
        case .deletion: UUID(uuidString: recordId).map { .dishDeletion(dishId: $0) }
        case .absence: nil
        }
    }

    func wire(of write: SyncWrite) -> SyncWrite.Wire? {
        if case .createDish(let writeId, let dish) = write {
            return .init(
                recordId: dish.id,
                body: .createDish(
                    .init(
                        id: writeId.canonicalString,
                        _type: .createDish,
                        dishId: dish.id.canonicalString,
                        mealId: dish.mealId.canonicalString,
                        name: dish.name,
                        positionInMeal: dish.positionInMeal
                    )
                ))
        }
        if case .deleteDish(let writeId, let dishId) = write {
            return .init(
                recordId: dishId,
                body: .deleteDish(
                    .init(
                        id: writeId.canonicalString, _type: .deleteDish,
                        dishId: dishId.canonicalString)))
        }
        if case .updateDish(let writeId, let correction) = write {
            return .init(
                recordId: correction.id,
                body: .updateDish(
                    .init(
                        id: writeId.canonicalString,
                        _type: .updateDish,
                        dishId: correction.id.canonicalString,
                        name: correction.name,
                        quantity: correction.quantity.map { quantity in
                            .init(
                                value: quantity.value,
                                proportionedIngredients: quantity.proportionedIngredients.map {
                                    .init(
                                        ingredientId: $0.ingredientId.canonicalString,
                                        quantity: $0.quantity)
                                })
                        }
                    )
                ))
        }
        return nil
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .dish(let dish) = change {
                return .value(id: dish.id, record: SyncChange.DishPayload(dish))
            }
            if case .dishDeletion(let dishId) = change {
                return .deletion(id: dishId)
            }
            return nil
        }

        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite? {
            if case .createDish(let write) = wire {
                return .createDish(
                    writeId: try uuid(write.id),
                    dish: NewDish(
                        id: try uuid(write.dishId),
                        mealId: try uuid(write.mealId),
                        name: write.name,
                        positionInMeal: write.positionInMeal))
            }
            if case .deleteDish(let write) = wire {
                return .deleteDish(writeId: try uuid(write.id), dishId: try uuid(write.dishId))
            }
            if case .updateDish(let write) = wire {
                return .updateDish(
                    writeId: try uuid(write.id),
                    correction: DishCorrection(
                        id: try uuid(write.dishId),
                        name: write.name,
                        quantity: try write.quantity.map { quantity in
                            DishCorrection.Quantity(
                                value: quantity.value,
                                proportionedIngredients: try quantity.proportionedIngredients.map {
                                    DishCorrection.ProportionedIngredient(
                                        ingredientId: try uuid($0.ingredientId),
                                        quantity: $0.quantity)
                                })
                        }))
            }
            return nil
        }
    #endif
}

extension SyncChange {
    /// 量と単位と出どころは、3つそろうか、3つとも無い（量の無い料理）。片方だけのときと、知らない出どころは nil にする
    struct DishPayload: Decodable {
        let id: String
        let mealId: String
        let name: String
        let quantity: Double?
        let unit: String?
        let quantitySource: String?
        let positionInMeal: Int
        let version: Int

        var syncedDish: SyncedDish? {
            guard let id = UUID(uuidString: id), let mealId = UUID(uuidString: mealId) else {
                return nil
            }
            let syncedQuantity: SyncedDish.Quantity?
            switch (quantity, unit, quantitySource.map(SyncedQuantitySource.init(rawValue:))) {
            case (nil, nil, nil):
                syncedQuantity = nil
            case (let value?, let unit?, let source??):
                syncedQuantity = SyncedDish.Quantity(value: value, unit: unit, source: source)
            // swiftlint:disable:next no_default_in_switch - 量・単位・出どころは、揃ってあるか揃って無いかのほかを読めないとみなす
            default:
                return nil
            }
            return SyncedDish(
                id: id, mealId: mealId, name: name, quantity: syncedQuantity,
                positionInMeal: positionInMeal, version: version)
        }
    }
}

#if DEBUG
    extension SyncChange.DishPayload: Encodable {
        fileprivate init(_ dish: SyncedDish) {
            self.init(
                id: dish.id.canonicalString, mealId: dish.mealId.canonicalString, name: dish.name,
                quantity: dish.quantity?.value, unit: dish.quantity?.unit,
                quantitySource: dish.quantity?.source.rawValue,
                positionInMeal: dish.positionInMeal, version: dish.version)
        }
    }
#endif
