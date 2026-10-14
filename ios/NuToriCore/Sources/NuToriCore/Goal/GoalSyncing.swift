public import Foundation
public import NuToriAPI

/// 目標の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct GoalSyncing: CacheApplying {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.goal

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 届いた順に目標を書く。閉じた目標は同じ ID で届き直すので、その値にそろえる。目標は消えない
    public func apply(_ changes: [SyncChange], to cache: any KeyedRecordCache<Goal, UUID>) throws {
        for goal in current(from: changes) {
            try cache.upsert(goal)
        }
    }

    public func erase(_ cache: any KeyedRecordCache<Goal, UUID>) throws {
        try cache.removeAll()
    }

    /// 取りに行った変更を、今の値の並び（届いた順）にする。日付が読めない目標は読み飛ばす
    public func current(from changes: [SyncChange]) -> [Goal] {
        changes.compactMap { change in
            guard case .goal(let synced) = change else { return nil }
            return Goal(synced)
        }
    }
}

extension Goal {
    /// 開始の日・期限・終わった日が読めない目標は nil
    init?(_ goal: SyncedGoal) {
        guard let startedDay = CalendarDay(yearMonthDay: goal.startedOn),
            let direction = Direction(goal.direction)
        else {
            return nil
        }
        var closure: Closure?
        if let synced = goal.closure {
            guard let endedDay = CalendarDay(yearMonthDay: synced.endedOn) else { return nil }
            closure = Closure(endedDay: endedDay, nextGoalId: synced.nextGoalId)
        }
        self.init(
            id: goal.id,
            startedDay: startedDay,
            startingWeightTrendKilograms: goal.startingWeightTrendKilograms,
            targetWeightKilograms: goal.targetWeightKilograms,
            decidedAt: goal.decidedAt,
            timeZone: goal.timeZone,
            direction: direction,
            closure: closure
        )
    }
}

extension Goal.Direction {
    init?(_ direction: SyncedGoal.Direction) {
        switch direction {
        case .lose(let weightChange):
            guard let weightChange = Goal.WeightChange(weightChange) else { return nil }
            self = .lose(weightChange)
        case .gain(let weightChange):
            guard let weightChange = Goal.WeightChange(weightChange) else { return nil }
            self = .gain(weightChange)
        case .maintain:
            self = .maintain
        }
    }
}

extension Goal.WeightChange {
    init?(_ weightChange: SyncedGoal.WeightChange) {
        guard let deadlineDay = CalendarDay(yearMonthDay: weightChange.deadlineOn) else {
            return nil
        }
        self.init(deadlineDay: deadlineDay, pacePlan: Goal.PacePlan(weightChange.pacePlan))
    }
}

extension Goal.PacePlan {
    init(_ pacePlan: SyncedGoal.PacePlan) {
        switch pacePlan {
        case .gentle: self = .gentle
        case .standard: self = .standard
        case .hard: self = .hard
        case .custom: self = .custom
        }
    }
}
