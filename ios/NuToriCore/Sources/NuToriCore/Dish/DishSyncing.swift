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

    /// 受け付けなかった作る・直す書き込みは、1行にし、サーバーに料理が無いときだけ、料理をキャッシュから外す。
    /// 値と削除の印は同期の働きが当てる（推定し直しで材料が入れ替わっていたときは、料理の量が料理の今の値に戻り、
    /// 置き換わった前の材料は、続けて取りに行く変更の削除の印で外れる）。
    /// 直す書き込みは、サーバーに値があれば直そうとした名前か量の「直せなかった」行、削除の印か無ければ端末で見せていた料理の「記録できなかった」行。
    /// 足した料理は、食事が無ければ「記録できなかった」行。消す書き込みは、サーバーが受け付けないことが無い
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?,
        shown: ShownRecords
    ) throws -> KindRejection {
        let pending = try PendingDishWrite(entry: entry)
        func rejected(_ meal: Meal, _ subject: RejectedMealLine.Subject) -> RejectedWrite {
            RejectedWrite(
                writeId: pending.writeId, reason: reason,
                record: .mealEdit(RejectedMealLine(meal: meal, subject: subject)))
        }
        switch (pending.write, current) {
        case (.create(let dish), .absent):
            return KindRejection(
                rejectedWrite: shown.meals[dish.mealId].map {
                    rejected(
                        $0,
                        .addedDish(
                            RejectedMealLine.DishPlace(
                                id: dish.id, name: dish.name, positionInMeal: dish.positionInMeal)))
                },
                removingChanges: [.dishDeletion(dishId: dish.id)])
        case (.update(let correction), .absent), (.rename(let correction), .absent):
            return KindRejection(
                rejectedWrite: shown.dishPlace(of: correction.id).map {
                    rejected($0.meal, .goneDish($0.place))
                },
                removingChanges: [.dishDeletion(dishId: correction.id)])
        case (.update(let correction), .deleted), (.rename(let correction), .deleted):
            return KindRejection(
                rejectedWrite: shown.dishPlace(of: correction.id).map {
                    rejected($0.meal, .goneDish($0.place))
                },
                removingChanges: [])
        case (.rename(let correction), .value):
            return KindRejection(
                rejectedWrite: shown.dishPlace(of: correction.id).map {
                    rejected($0.meal, .dishName($0.place, attempted: correction.name))
                },
                removingChanges: [])
        case (.update(let correction), .value):
            guard let quantity = correction.quantity,
                let unit = shown.dishes[correction.id]?.quantity?.unit
            else { return KindRejection.none }
            return KindRejection(
                rejectedWrite: shown.dishPlace(of: correction.id).map {
                    rejected(
                        $0.meal, .dishQuantity($0.place, attempted: quantity.value, unit: unit))
                },
                removingChanges: [])
        case (.create, .value), (.create, .deleted), (.create, nil), (.update, nil),
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

extension DishSyncing {
    /// 送り待ちに料理を足す・名前を直す書き込みがある料理。送った端末で、送り終えて料理ごとの推定の状態が届くまで料理をまだ送れていないとして見せる
    /// （受け付けた書き込みも、変更を取り切るまで送り待ちに残る。`SyncEngine` の `resolve`）。
    /// 読めない送り待ちと、ほかの種類の送り待ちは読み飛ばす
    public static func unsentDishIds(in entries: [PendingEntry]) -> Set<UUID> {
        Set(
            entries.filter { $0.kind == DishSyncing.kindName }
                .compactMap { try? PendingDishWrite(entry: $0) }
                .compactMap { pending in
                    switch pending.write {
                    case .create(let dish): dish.id
                    case .rename(let correction): correction.id
                    case .update, .delete: nil
                    }
                })
    }
}
