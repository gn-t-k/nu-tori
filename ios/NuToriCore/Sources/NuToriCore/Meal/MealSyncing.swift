public import Foundation
public import NuToriAPI

/// 食事の同期の形。記録の種類の入口のうち、キャッシュの型に依らない部分。
/// 取りに行った変更の見分け方と今の値の読み方、送り待ちから送る書き込み（作る・消す）を作る
public struct MealSyncing: SyncedRecordKind, RecordKindWrites {
    /// 送り待ちの種類の名前。変えると、送り待ちに残った食事が読めなくなる
    public static let kindName = RecordKindName.meal

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { self }

    /// 取りに行った変更のうち、当てる今の値と、消す食事の ID
    public struct Current: Sendable, Equatable {
        public let meals: [Meal]
        public let removedMealIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let pending = try PendingMealWrite(entry: entry)
        switch pending.write {
        case .create(let meal):
            return .createMeal(writeId: pending.writeId, meal: SyncedMeal(meal))
        case .delete(let mealId):
            return .deleteMeal(writeId: pending.writeId, mealId: mealId)
        }
    }

    /// 受け付けなかった作る書き込みは、サーバーに食事が無いときだけ、カードを外して行にする。
    /// 削除の印のときは、その食事はもう消されているので行を出さない。値があるときは、カードがそのまま残る。
    /// 消す書き込みは、サーバーが受け付けないことが無い
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?
    ) throws -> KindRejection {
        let pending = try PendingMealWrite(entry: entry)
        switch (pending.write, current) {
        case (.create(let meal), .absent):
            return KindRejection(
                rejectedWrite: RejectedWrite(
                    writeId: pending.writeId, reason: reason, record: .meal(meal)),
                removingChanges: [.mealDeletion(mealId: meal.id)]
            )
        case (.create, .value), (.create, .deleted), (.create, nil), (.delete, _):
            return KindRejection.none
        }
    }

    /// 食事を記録したときの結果。送り待ちに足し、食事を、取りに行った変更と同じ形でキャッシュに当てる
    public func recording(_ meal: Meal, enqueuing write: PendingMealWrite) throws -> SyncBoxResult {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [KindChanges(kind: name, changes: [.meal(SyncedMeal(meal))])]
        )
    }

    /// 食事を消したときの結果。送り待ちに足し、食事と推定の状態を、削除の印と同じ形でキャッシュから消す
    public func deleting(mealId: UUID, enqueuing write: PendingMealWrite) throws -> SyncBoxResult {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [
                KindChanges(kind: name, changes: [.mealDeletion(mealId: mealId)]),
                MealEstimationStatusSyncing.removing(mealId: mealId),
            ]
        )
    }

    /// 取りに行った変更を、今の値の並びにする。削除の印は、置き場に無い ID でも読み飛ばせるよう ID だけを返す
    public func current(from changes: [SyncChange]) -> Current {
        var meals: [Meal] = []
        var removedMealIds: [UUID] = []
        for change in changes {
            if case .meal(let meal) = change {
                meals.append(Meal(meal))
            } else if case .mealDeletion(let mealId) = change {
                removedMealIds.append(mealId)
            }
        }
        return Current(meals: meals, removedMealIds: removedMealIds)
    }
}

extension SyncedMeal {
    init(_ meal: Meal) {
        self.init(
            id: meal.id,
            eatenAt: meal.eatenAt,
            eatenUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
            sentAt: meal.sentAt,
            sentTimeZone: meal.sentTimeZone,
            entryMethod: SyncedMeal.EntryMethod(meal.entry),
            photoIds: meal.photoIds
        )
    }
}

extension Meal {
    init(_ meal: SyncedMeal) {
        self.init(
            id: meal.id,
            eatenAt: meal.eatenAt,
            eatenUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
            sentAt: meal.sentAt,
            sentTimeZone: meal.sentTimeZone,
            entry: MealDraft.Entry(meal.entryMethod),
            photoIds: meal.photoIds
        )
    }
}

extension SyncedMeal.EntryMethod {
    init(_ entry: MealDraft.Entry) {
        switch entry {
        case .captured: self = .captured
        case .picked: self = .picked
        }
    }
}

extension MealDraft.Entry {
    init(_ entryMethod: SyncedMeal.EntryMethod) {
        switch entryMethod {
        case .captured: self = .captured
        case .picked: self = .picked
        }
    }
}
