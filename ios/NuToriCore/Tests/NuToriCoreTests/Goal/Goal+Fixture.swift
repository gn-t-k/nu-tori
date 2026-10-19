import Foundation
import NuToriAPI
import NuToriCore
import Testing

extension Goal {
    /// 2026-10-01（東京）に決めた、12月24日までに 72.4 kg から 68.0 kg へ減らす標準の目標。
    /// 既定では、10月1日に始め、達成も期限の日の確定も無く、閉じていない
    static func losing(
        id: UUID = UUID(),
        startedOn startedDay: CalendarDay = CalendarDay(year: 2026, month: 10, day: 1),
        achievement: Achievement? = nil, deadlineConfirmation: DeadlineConfirmation? = nil,
        closure: Closure? = nil
    ) throws -> Goal {
        Goal(
            id: id,
            startedDay: startedDay,
            startingWeightTrendKilograms: 72.4,
            targetWeightKilograms: 68.0,
            decidedAt: try Date("2026-10-01T08:30:00+09:00", strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            direction: .lose(
                WeightChange(
                    deadlineDay: CalendarDay(year: 2026, month: 12, day: 24), pacePlan: .standard)),
            achievement: achievement,
            deadlineConfirmation: deadlineConfirmation,
            closure: closure
        )
    }

    /// `decidedAt`（東京）に決めた、`kilograms` を保つ目標。既定では、2026-10-20 21:00 に決めた 65.0 kg を保つ目標で、閉じていない
    static func maintaining(
        id: UUID = UUID(),
        startedOn startedDay: CalendarDay = CalendarDay(year: 2026, month: 10, day: 20),
        kilograms: Double = 65.0, decidedAt: String = "2026-10-20T21:00:00+09:00",
        closure: Closure? = nil
    ) throws -> Goal {
        Goal(
            id: id,
            startedDay: startedDay,
            startingWeightTrendKilograms: kilograms,
            targetWeightKilograms: kilograms,
            decidedAt: try Date(decidedAt, strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            direction: .maintain,
            achievement: nil,
            deadlineConfirmation: nil,
            closure: closure
        )
    }
}

extension Goal.Achievement {
    /// `judgedAt`（東京）に判定した、`day` の達成
    static func inTokyo(on day: CalendarDay, judgedAt: String) throws -> Goal.Achievement {
        Goal.Achievement(
            achievedDay: day, judgedAt: try Date(judgedAt, strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
    }
}

extension Goal.DeadlineConfirmation {
    /// `confirmedAt`（東京）に確定した、期限の日の体重の傾向
    static func inTokyo(weightTrendKilograms: Double, confirmedAt: String) throws
        -> Goal.DeadlineConfirmation
    {
        Goal.DeadlineConfirmation(
            deadlineWeightTrendKilograms: weightTrendKilograms,
            confirmedAt: try Date(confirmedAt, strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
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
            achievement: nil,
            deadlineConfirmation: nil,
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
            achievement: nil,
            deadlineConfirmation: nil,
            closure: nil
        )
    }
}
