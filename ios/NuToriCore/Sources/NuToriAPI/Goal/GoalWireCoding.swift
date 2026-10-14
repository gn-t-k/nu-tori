import Foundation

/// 目標は消えないので、削除の印を持たない
struct GoalWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.goal

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.GoalPayload.self).syncedGoal).map { .goal($0) }
        case .deletion, .absence: nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .goal(let goal) = change else { return nil }
            return .value(id: goal.id, record: SyncChange.GoalPayload(goal))
        }
    #endif
}

extension SyncChange {
    /// 読めない ID・タイムゾーンと、知らない向き・速さの案は nil にする。
    /// サーバーが値を足しても、古い版のアプリは前の目標のまま同期を続ける
    struct GoalPayload: Decodable {
        let id: String
        let startedOn: String
        let startingWeightTrendKg: Double
        let targetWeightKg: Double
        let decidedAt: Int
        let timeZone: String
        let direction: String
        /// 減量・増量の目標だけに付く
        let weightChange: WeightChange?
        /// 閉じた目標だけに付く
        let closure: Closure?

        struct WeightChange: Decodable {
            let deadlineOn: String
            let pacePlan: String
        }

        struct Closure: Decodable {
            let endedOn: String
            let nextGoalId: String
        }

        var syncedGoal: SyncedGoal? {
            var syncedWeightChange: SyncedGoal.WeightChange?
            if let weightChange {
                guard let pacePlan = SyncedGoal.PacePlan(rawValue: weightChange.pacePlan) else {
                    return nil
                }
                syncedWeightChange = .init(deadlineOn: weightChange.deadlineOn, pacePlan: pacePlan)
            }
            var syncedClosure: SyncedGoal.Closure?
            if let closure {
                guard let nextGoalId = UUID(uuidString: closure.nextGoalId) else { return nil }
                syncedClosure = .init(endedOn: closure.endedOn, nextGoalId: nextGoalId)
            }
            guard let id = UUID(uuidString: id),
                let timeZone = TimeZone(identifier: timeZone),
                let direction = SyncedGoal.Direction(
                    serverName: direction, weightChange: syncedWeightChange)
            else {
                return nil
            }
            return SyncedGoal(
                id: id,
                startedOn: startedOn,
                startingWeightTrendKilograms: startingWeightTrendKg,
                targetWeightKilograms: targetWeightKg,
                decidedAt: Date(millisecondsSince1970: decidedAt),
                timeZone: timeZone,
                direction: direction,
                closure: syncedClosure
            )
        }
    }
}

#if DEBUG
    extension SyncChange.GoalPayload: Encodable {
        fileprivate init(_ goal: SyncedGoal) {
            self.init(
                id: goal.id.canonicalString,
                startedOn: goal.startedOn,
                startingWeightTrendKg: goal.startingWeightTrendKilograms,
                targetWeightKg: goal.targetWeightKilograms,
                decidedAt: goal.decidedAt.millisecondsSince1970,
                timeZone: goal.timeZone.identifier,
                direction: goal.direction.serverName,
                weightChange: goal.direction.weightChange.map {
                    .init(deadlineOn: $0.deadlineOn, pacePlan: $0.pacePlan.rawValue)
                },
                closure: goal.closure.map {
                    .init(endedOn: $0.endedOn, nextGoalId: $0.nextGoalId.canonicalString)
                }
            )
        }
    }
    extension SyncChange.GoalPayload.WeightChange: Encodable {}
    extension SyncChange.GoalPayload.Closure: Encodable {}
#endif
