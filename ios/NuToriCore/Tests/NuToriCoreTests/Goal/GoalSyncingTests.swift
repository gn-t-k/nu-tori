import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("目標の同期の形")
struct GoalSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = GoalSyncing()
        let cache: MemoryKeyedRecordCache<Goal, UUID>
        let losing: Goal
        let maintaining: Goal

        init() throws {
            (cache, losing, maintaining) = try Self.appliedCache()
        }

        /// 減量の目標と維持の目標を当てたキャッシュ
        static func appliedCache() throws -> (
            cache: MemoryKeyedRecordCache<Goal, UUID>, losing: Goal, maintaining: Goal
        ) {
            let cache = MemoryKeyedRecordCache<Goal, UUID>(id: \.id)
            let losing = try Goal.losing()
            let maintaining = try Goal.maintaining()
            try GoalSyncing().apply(
                [
                    .goal(try .losing(id: losing.id)),
                    .goal(try .maintaining(id: maintaining.id)),
                ], to: cache)
            return (cache, losing, maintaining)
        }

        @Test("届いた目標が、向き・期限・速さの案を持った今の値でキャッシュに入ること")
        func storesArrivedGoals() {
            #expect(Set(cache.all()) == [losing, maintaining])
        }

        @Suite("立て直して、閉じた前の目標が届き直したとき")
        struct ClosedArrivedAgain {
            let syncing = GoalSyncing()
            let cache: MemoryKeyedRecordCache<Goal, UUID>
            let losing: Goal
            let maintaining: Goal

            init() throws {
                (cache, losing, maintaining) = try Applying.appliedCache()
            }

            @Test("キャッシュの目標が、終わった日と次の目標の ID と切り替えた終わり方を持つこと")
            func overwritesWithClosure() throws {
                try syncing.apply(
                    [
                        .goal(
                            try .losing(
                                id: losing.id,
                                closure: .init(
                                    endedOn: "2026-10-20", nextGoalId: maintaining.id,
                                    endReason: .switched)))
                    ], to: cache)

                let closed = try Goal.losing(
                    id: losing.id,
                    closure: Goal.Closure(
                        endedDay: CalendarDay(year: 2026, month: 10, day: 20),
                        nextGoalId: maintaining.id, endReason: .switched))
                #expect(Set(cache.all()) == [closed, maintaining])
            }
        }

        @Suite("達成して期限の日を確定し、期限後の維持に移って閉じた目標が届き直したとき")
        struct FinishedArrivedAgain {
            let syncing = GoalSyncing()
            let cache: MemoryKeyedRecordCache<Goal, UUID>
            let losing: Goal
            let maintaining: Goal
            let tokyo: TimeZone
            let losAngeles: TimeZone

            init() throws {
                (cache, losing, maintaining) = try Applying.appliedCache()
                tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
                losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
            }

            static func synced(
                id: UUID, nextGoalId: UUID, achievedOn: String = "2026-12-10"
            ) throws -> SyncedGoal {
                let losing = try SyncedGoal.losing(id: id)
                return SyncedGoal(
                    id: id, startedOn: losing.startedOn,
                    startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                    targetWeightKilograms: losing.targetWeightKilograms,
                    decidedAt: losing.decidedAt, timeZone: losing.timeZone,
                    direction: losing.direction,
                    achievement: .init(
                        achievedOn: achievedOn,
                        judgedAt: try Date("2026-12-11T07:00:00+09:00", strategy: .iso8601),
                        timeZone: losing.timeZone),
                    deadlineConfirmation: .init(
                        deadlineWeightTrendKilograms: 67.8,
                        confirmedAt: try Date("2026-12-25T07:00:00-08:00", strategy: .iso8601),
                        timeZone: try #require(TimeZone(identifier: "America/Los_Angeles"))),
                    closure: .init(
                        endedOn: "2026-12-28", nextGoalId: nextGoalId,
                        endReason: .movedToMaintenance))
            }

            @Test("キャッシュの目標が、達成した日・期限の日の体重の傾向・終わり方を持つこと")
            func overwritesWithFinish() throws {
                try syncing.apply(
                    [.goal(try Self.synced(id: losing.id, nextGoalId: maintaining.id))],
                    to: cache)

                let finished = try #require(cache.all().first { $0.id == losing.id })
                #expect(
                    finished.achievement
                        == Goal.Achievement(
                            achievedDay: CalendarDay(year: 2026, month: 12, day: 10),
                            judgedAt: try Date("2026-12-11T07:00:00+09:00", strategy: .iso8601),
                            timeZone: tokyo))
                #expect(
                    finished.deadlineConfirmation
                        == Goal.DeadlineConfirmation(
                            deadlineWeightTrendKilograms: 67.8,
                            confirmedAt: try Date("2026-12-25T07:00:00-08:00", strategy: .iso8601),
                            timeZone: losAngeles))
                #expect(
                    finished.closure
                        == Goal.Closure(
                            endedDay: CalendarDay(year: 2026, month: 12, day: 28),
                            nextGoalId: maintaining.id, endReason: .movedToMaintenance))
            }

            @Test("達成した日が読めない目標は、キャッシュの前の値のままにすること")
            func skipsUnreadableAchievedDay() throws {
                try syncing.apply(
                    [
                        .goal(
                            try Self.synced(
                                id: losing.id, nextGoalId: maintaining.id, achievedOn: "12月10日"))
                    ], to: cache)

                #expect(Set(cache.all()) == [losing, maintaining])
            }
        }

        @Test("開始の日が読めない目標は、キャッシュに入れないこと")
        func skipsUnreadableStartedDay() throws {
            try syncing.apply([.goal(try .losing(id: UUID(), startedOn: "10月1日"))], to: cache)

            #expect(Set(cache.all()) == [losing, maintaining])
        }

        @Test("期限が読めない目標は、キャッシュに入れないこと")
        func skipsUnreadableDeadline() throws {
            try syncing.apply([.goal(try .losing(id: UUID(), deadlineOn: "年末"))], to: cache)

            #expect(Set(cache.all()) == [losing, maintaining])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.mealDeletion(mealId: losing.id)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、目標がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
