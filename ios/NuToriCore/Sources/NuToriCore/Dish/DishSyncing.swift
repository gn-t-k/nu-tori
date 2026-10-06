public import Foundation
public import NuToriAPI

/// 料理の同期の形。端末も書く種類で、料理を足す・直す・消す書き込みを送り待ちから送る
public struct DishSyncing: SyncedRecordKind, RecordKindWrites {
    /// 送り待ちの種類の名前。変えると、送り待ちに残った料理が読めなくなる
    public static let kindName = RecordKindName.dish

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { self }

    /// 取りに行った変更のうち、当てる今の値（届いた順）と、消す料理の ID
    public struct Current: Sendable, Equatable {
        public let dishes: [Dish]
        public let removedDishIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let pending = try PendingDishWrite(entry: entry)
        switch pending.write {
        case .create(let dish):
            return .createDish(writeId: pending.writeId, dish: dish)
        case .update(let correction), .rename(let correction):
            return .updateDish(writeId: pending.writeId, correction: correction)
        case .delete(let dishId):
            return .deleteDish(writeId: pending.writeId, dishId: dishId)
        }
    }

    /// 受け付けなかった作る・直す書き込みは、サーバーに料理が無いときだけ、料理をキャッシュから外す。
    /// 値と削除の印は同期の働きが当てる（推定し直しで材料が入れ替わっていたときは、料理の量が料理の今の値に戻り、
    /// 置き換わった前の材料は、続けて取りに行く変更の削除の印で外れる）。画面に出す1行は、見え方のチケットで足す。
    /// 消す書き込みは、サーバーが受け付けないことが無い
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?
    ) throws -> KindRejection {
        let pending = try PendingDishWrite(entry: entry)
        switch (pending.write, current) {
        case (.create(let dish), .absent):
            return KindRejection(
                rejectedWrite: nil, removingChanges: [.dishDeletion(dishId: dish.id)])
        case (.update(let correction), .absent), (.rename(let correction), .absent):
            return KindRejection(
                rejectedWrite: nil, removingChanges: [.dishDeletion(dishId: correction.id)])
        case (.create, .value), (.create, .deleted), (.create, nil), (.update, .value),
            (.update, .deleted), (.update, nil), (.rename, .value), (.rename, .deleted),
            (.rename, nil), (.delete, _):
            return KindRejection.none
        }
    }

    /// 料理を足したときの結果。送り待ちに足し、料理を、取りに行った変更と同じ形でキャッシュに当てる
    public func adding(_ dish: Dish, enqueuing write: PendingDishWrite) throws -> SyncBoxResult {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [KindChanges(kind: name, changes: [.dish(SyncedDish(dish))])]
        )
    }

    /// 料理を直したときの結果。送り待ちに足し、直した料理と、比例で量を変えた材料をキャッシュに当てる
    public func correcting(_ edit: DishEdit, enqueuing write: PendingDishWrite) throws
        -> SyncBoxResult
    {
        var kindChanges = [KindChanges(kind: name, changes: [.dish(SyncedDish(edit.dish))])]
        if !edit.ingredients.isEmpty {
            kindChanges.append(
                KindChanges(
                    kind: IngredientSyncing.kindName,
                    changes: edit.ingredients.map { .ingredient(SyncedIngredient($0)) }))
        }
        return SyncBoxResult(enqueuing: [try write.entry()], kindChanges: kindChanges)
    }

    /// 料理を消したときの結果。送り待ちに足し、料理と材料と料理ごとの推定の状態を、削除の印と同じ形でキャッシュから消す
    public func deleting(
        dishId: UUID, ingredientIds: [UUID], enqueuing write: PendingDishWrite
    ) throws -> SyncBoxResult {
        var kindChanges = [
            KindChanges(kind: name, changes: [.dishDeletion(dishId: dishId)]),
            DishEstimationStatusSyncing.removing(dishId: dishId),
        ]
        if !ingredientIds.isEmpty {
            kindChanges.append(
                KindChanges(
                    kind: IngredientSyncing.kindName,
                    changes: ingredientIds.map { .ingredientDeletion(ingredientId: $0) }))
        }
        return SyncBoxResult(enqueuing: [try write.entry()], kindChanges: kindChanges)
    }

    /// 取りに行った変更を、今の値の並びにする。食事より先に届いた料理も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> Current {
        var dishes: [Dish] = []
        var removedDishIds: [UUID] = []
        for change in changes {
            if case .dish(let synced) = change {
                dishes.append(Dish(synced))
            } else if case .dishDeletion(let dishId) = change {
                removedDishIds.append(dishId)
            }
        }
        return Current(dishes: dishes, removedDishIds: removedDishIds)
    }
}

extension Dish {
    init(_ dish: SyncedDish) {
        self.init(
            id: dish.id,
            mealId: dish.mealId,
            name: dish.name,
            quantity: dish.quantity.map {
                Quantity(value: $0.value, unit: $0.unit, source: QuantitySource($0.source))
            },
            positionInMeal: dish.positionInMeal,
            version: dish.version
        )
    }
}

extension SyncedDish {
    init(_ dish: Dish) {
        self.init(
            id: dish.id,
            mealId: dish.mealId,
            name: dish.name,
            quantity: dish.quantity.map {
                Quantity(value: $0.value, unit: $0.unit, source: SyncedQuantitySource($0.source))
            },
            positionInMeal: dish.positionInMeal,
            version: dish.version
        )
    }
}
