public import Foundation
public import NuToriAPI

/// 料理の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct DishSyncing: SyncedRecordKind {
    public static let kindName = RecordKindName.dish

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    /// 取りに行った変更のうち、当てる今の値（届いた順）と、消す料理の ID
    public struct Current: Sendable, Equatable {
        public let dishes: [Dish]
        public let removedDishIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        switch change {
        case .dish, .dishDeletion: true
        case .weightRecord, .weightRecordDeletion, .accountSettings, .ingredient,
            .ingredientDeletion, .meal, .mealDeletion, .mealEstimationStatus,
            .mealEstimationStatusDeletion, .unknown:
            false
        }
    }

    /// 取りに行った変更を、今の値の並びにする。食事より先に届いた料理も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> Current {
        var dishes: [Dish] = []
        var removedDishIds: [UUID] = []
        for change in changes {
            switch change {
            case .dish(let synced): dishes.append(Dish(synced))
            case .dishDeletion(let dishId): removedDishIds.append(dishId)
            case .weightRecord, .weightRecordDeletion, .accountSettings, .ingredient,
                .ingredientDeletion, .meal, .mealDeletion, .mealEstimationStatus,
                .mealEstimationStatusDeletion, .unknown:
                break
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
            quantity: dish.quantity,
            unit: dish.unit,
            positionInMeal: dish.positionInMeal,
            version: dish.version
        )
    }
}
