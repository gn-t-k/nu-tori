import Foundation
import NuToriAPI
import NuToriCore
import Testing

extension Goal {
    /// 2026-10-01（東京）に決めた、12月24日までに 72.4 kg から 68.0 kg へ減らす標準の目標。閉じていない
    static func losing(id: UUID = UUID(), closure: Closure? = nil) throws -> Goal {
        Goal(
            id: id,
            startedDay: CalendarDay(year: 2026, month: 10, day: 1),
            startingWeightTrendKilograms: 72.4,
            targetWeightKilograms: 68.0,
            decidedAt: try Date("2026-10-01T08:30:00+09:00", strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            direction: .lose(
                WeightChange(
                    deadlineDay: CalendarDay(year: 2026, month: 12, day: 24), pacePlan: .standard)),
            closure: closure
        )
    }

    /// 2026-10-20（東京）に決めた、65.0 kg を保つ目標
    static func maintaining(id: UUID = UUID()) throws -> Goal {
        Goal(
            id: id,
            startedDay: CalendarDay(year: 2026, month: 10, day: 20),
            startingWeightTrendKilograms: 65.0,
            targetWeightKilograms: 65.0,
            decidedAt: try Date("2026-10-20T21:00:00+09:00", strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            direction: .maintain,
            closure: nil
        )
    }
}

extension SyncedGoal {
    /// `Goal.losing()` が届くときの形
    static func losing(
        id: UUID, startedOn: String = "2026-10-01", deadlineOn: String = "2026-12-24",
        closure: Closure? = nil
    ) throws -> SyncedGoal {
        SyncedGoal(
            id: id,
            startedOn: startedOn,
            startingWeightTrendKilograms: 72.4,
            targetWeightKilograms: 68.0,
            decidedAt: try Date("2026-10-01T08:30:00+09:00", strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            direction: .lose(.init(deadlineOn: deadlineOn, pacePlan: .standard)),
            closure: closure
        )
    }

    /// `Goal.maintaining()` が届くときの形
    static func maintaining(id: UUID) throws -> SyncedGoal {
        SyncedGoal(
            id: id,
            startedOn: "2026-10-20",
            startingWeightTrendKilograms: 65.0,
            targetWeightKilograms: 65.0,
            decidedAt: try Date("2026-10-20T21:00:00+09:00", strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            direction: .maintain,
            closure: nil
        )
    }
}
