import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("1日の目安の同期の形")
struct DailyGuideSyncingTests {
    /// 10月1日から当てる 1,850 kcal の1日の目安が届くときの形
    static func synced(
        id: UUID, goalId: UUID, expenditureEstimateId: UUID, effectiveOn: String = "2026-10-01",
        energyKilocalories: Int = 1850, limitHits: [SyncedDailyGuide.LimitHit] = []
    ) -> SyncedDailyGuide {
        SyncedDailyGuide(
            id: id, goalId: goalId, expenditureEstimateId: expenditureEstimateId,
            effectiveOn: effectiveOn, energyKilocalories: energyKilocalories, proteinGrams: 130,
            fatGrams: 50, carbohydrateGrams: 220, limitHits: limitHits)
    }

    @Suite("目標も推定消費カロリーも届いていないうちに、1日の目安が届いたとき")
    struct ArrivedBeforeGoal {
        let syncing = DailyGuideSyncing()
        let cache = MemoryKeyedRecordCache<DailyGuide, UUID>(id: \.id)
        let guideId = UUID()
        let goalId = UUID()
        let expenditureEstimateId = UUID()

        @Test("目標の ID と推定の ID を値で持ったまま、キャッシュに入ること")
        func storesGuideWithoutParent() throws {
            try syncing.apply(
                [
                    .dailyGuide(
                        DailyGuideSyncingTests.synced(
                            id: guideId, goalId: goalId,
                            expenditureEstimateId: expenditureEstimateId,
                            limitHits: [.minimumEnergy, .weeklyChange]))
                ], to: cache)

            #expect(
                cache.all() == [
                    DailyGuide(
                        id: guideId, goalId: goalId, expenditureEstimateId: expenditureEstimateId,
                        effectiveDay: CalendarDay(year: 2026, month: 10, day: 1),
                        energyKilocalories: 1850, proteinGrams: 130, fatGrams: 50,
                        carbohydrateGrams: 220, limitHits: [.minimumEnergy, .weeklyChange])
                ])
        }
    }

    @Suite("1日の目安を当てたあと")
    struct Applied {
        let syncing = DailyGuideSyncing()
        let cache = MemoryKeyedRecordCache<DailyGuide, UUID>(id: \.id)
        let guideId = UUID()
        let goalId = UUID()
        let expenditureEstimateId = UUID()

        init() throws {
            try syncing.apply(
                [
                    .dailyGuide(
                        DailyGuideSyncingTests.synced(
                            id: guideId, goalId: goalId,
                            expenditureEstimateId: expenditureEstimateId))
                ], to: cache)
        }

        @Test("同じ1日の目安が届き直すと、行を増やさずその値にそろえること")
        func overwritesWithArrivedValue() throws {
            try syncing.apply(
                [
                    .dailyGuide(
                        DailyGuideSyncingTests.synced(
                            id: guideId, goalId: goalId,
                            expenditureEstimateId: expenditureEstimateId,
                            energyKilocalories: 1900))
                ], to: cache)

            #expect(cache.all().map(\.energyKilocalories) == [1900])
        }

        @Test("当てる始まりの日が読めない1日の目安は、キャッシュに入れないこと")
        func skipsUnreadableEffectiveDay() throws {
            try syncing.apply(
                [
                    .dailyGuide(
                        DailyGuideSyncingTests.synced(
                            id: UUID(), goalId: goalId,
                            expenditureEstimateId: expenditureEstimateId, effectiveOn: "来週"))
                ], to: cache)

            #expect(cache.all().map(\.id) == [guideId])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.mealDeletion(mealId: guideId)], to: cache)

            #expect(cache.all().map(\.id) == [guideId])
        }

        @Test("空にすると、1日の目安がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
