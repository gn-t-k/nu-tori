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

            @Test("キャッシュの目標が、終わった日と次の目標の ID を持つこと")
            func overwritesWithClosure() throws {
                try syncing.apply(
                    [
                        .goal(
                            try .losing(
                                id: losing.id,
                                closure: .init(endedOn: "2026-10-20", nextGoalId: maintaining.id)))
                    ], to: cache)

                let closed = try Goal.losing(
                    id: losing.id,
                    closure: Goal.Closure(
                        endedDay: CalendarDay(year: 2026, month: 10, day: 20),
                        nextGoalId: maintaining.id))
                #expect(Set(cache.all()) == [closed, maintaining])
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
