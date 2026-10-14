import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("目標のキャッシュの行")
struct CachedGoalCacheTests {
    /// 2026-10-01（東京）に決めた、12月24日までに 72.4 kg から 68.0 kg へ減らす、自分で決めた目標
    static func losing(id: UUID = UUID(), closure: Goal.Closure? = nil) throws -> Goal {
        Goal(
            id: id, startedDay: CalendarDay(year: 2026, month: 10, day: 1),
            startingWeightTrendKilograms: 72.4, targetWeightKilograms: 68.0,
            decidedAt: Date(timeIntervalSince1970: 1_790_812_800),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            direction: .lose(
                Goal.WeightChange(
                    deadlineDay: CalendarDay(year: 2026, month: 12, day: 24), pacePlan: .custom)),
            closure: closure)
    }

    /// 2026-10-20（ロサンゼルス）に決めた、65.0 kg を保つ目標
    static func maintaining(id: UUID = UUID()) throws -> Goal {
        Goal(
            id: id, startedDay: CalendarDay(year: 2026, month: 10, day: 20),
            startingWeightTrendKilograms: 65.0, targetWeightKilograms: 65.0,
            decidedAt: Date(timeIntervalSince1970: 1_792_454_400),
            timeZone: try #require(TimeZone(identifier: "America/Los_Angeles")),
            direction: .maintain, closure: nil)
    }

    /// 減量の目標と維持の目標を保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedGoal>,
        losing: Goal, maintaining: Goal
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedGoal>(context: store.container.mainContext)
        let losing = try losing()
        let maintaining = try maintaining()
        try cache.upsert(losing)
        try cache.upsert(maintaining)
        try cache.context.save()
        return (store, cache, losing, maintaining)
    }

    @Suite("減量の目標と維持の目標を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedGoal>
        let losing: Goal
        let maintaining: Goal

        init() throws {
            (store, cache, losing, maintaining) = try CachedGoalCacheTests.filledCache()
        }

        @Test("足した目標と同じ目標を、向き・期限・速さの案を保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [losing, maintaining])
        }

        @Test("同じ ID の閉じた目標を足すと、行を増やさず、終わった日と次の目標を持つこと")
        func replacesWithClosure() throws {
            let closed = try CachedGoalCacheTests.losing(
                id: losing.id,
                closure: Goal.Closure(
                    endedDay: CalendarDay(year: 2026, month: 10, day: 20),
                    nextGoalId: maintaining.id))

            try cache.upsert(closed)

            let saved = try cache.savedRecords()
            #expect(saved.count == 2)
            #expect(Set(saved) == [closed, maintaining])
        }

        @Test("同じ ID の維持の目標を足すと、期限と速さの案が無くなること")
        func replacesWithMaintaining() throws {
            let replaced = try CachedGoalCacheTests.maintaining(id: losing.id)

            try cache.upsert(replaced)

            #expect(Set(try cache.savedRecords()) == [replaced, maintaining])
        }

        @Test("ID で消すと、その目標の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: losing.id)

            #expect(try cache.savedRecords() == [maintaining])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("知らない向き・知らない速さの案・期限の無い減量・読めない開始の日・次の目標の無い閉じた行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedGoal>
        let readable: Goal

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = try CachedGoalCacheTests.maintaining()
            let unknownDirection = try CachedGoalCacheTests.maintaining()
            let unknownPacePlan = try CachedGoalCacheTests.losing()
            let withoutDeadline = try CachedGoalCacheTests.losing()
            let unreadableStartedDay = try CachedGoalCacheTests.maintaining()
            let closedWithoutNextGoal = try CachedGoalCacheTests.maintaining()
            for goal in [
                readable, unknownDirection, unknownPacePlan, withoutDeadline,
                unreadableStartedDay, closedWithoutNextGoal,
            ] {
                try cache.upsert(goal)
            }
            try #require(try CachedGoal.find(id: unknownDirection.id, in: context)).direction =
                "recompose"
            try #require(try CachedGoal.find(id: unknownPacePlan.id, in: context)).pacePlan =
                "extreme"
            try #require(try CachedGoal.find(id: withoutDeadline.id, in: context)).deadlineDay = nil
            try #require(try CachedGoal.find(id: unreadableStartedDay.id, in: context))
                .startedDay = "2026/10/20"
            try #require(try CachedGoal.find(id: closedWithoutNextGoal.id, in: context)).endedDay =
                "2026-11-01"
            try context.save()
        }

        @Test("読めない行を飛ばし、読める目標だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
