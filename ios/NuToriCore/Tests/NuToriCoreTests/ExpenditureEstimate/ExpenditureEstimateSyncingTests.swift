import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("推定消費カロリーの同期の形")
struct ExpenditureEstimateSyncingTests {
    static let estimatedAt = Date(timeIntervalSince1970: 1_790_812_800)

    /// 10月1日から当てる 2,300 kcal の推定が届くときの形
    static func synced(
        id: UUID, effectiveOn: String = "2026-10-01", expenditureKilocalories: Int = 2300,
        initialSource: SyncedExpenditureEstimate.InitialSource? = .backCalculated
    ) -> SyncedExpenditureEstimate {
        SyncedExpenditureEstimate(
            id: id, effectiveOn: effectiveOn, expenditureKilocalories: expenditureKilocalories,
            estimatedAt: estimatedAt, initialSource: initialSource)
    }

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = ExpenditureEstimateSyncing()
        let cache = MemoryKeyedRecordCache<ExpenditureEstimate, UUID>(id: \.id)
        let initialId = UUID()
        let laterId = UUID()

        init() throws {
            try syncing.apply(
                [
                    .expenditureEstimate(ExpenditureEstimateSyncingTests.synced(id: initialId)),
                    .expenditureEstimate(
                        ExpenditureEstimateSyncingTests.synced(
                            id: laterId, effectiveOn: "2026-10-08", expenditureKilocalories: 2250,
                            initialSource: nil)),
                ], to: cache)
        }

        @Test("推定の始まりは出どころを持ち、そのあとの推定は出どころを持たずに、キャッシュに入ること")
        func storesArrivedEstimates() {
            #expect(
                Set(cache.all()) == [
                    ExpenditureEstimate(
                        id: initialId, effectiveDay: CalendarDay(year: 2026, month: 10, day: 1),
                        expenditureKilocalories: 2300,
                        estimatedAt: ExpenditureEstimateSyncingTests.estimatedAt,
                        initialSource: .backCalculated),
                    ExpenditureEstimate(
                        id: laterId, effectiveDay: CalendarDay(year: 2026, month: 10, day: 8),
                        expenditureKilocalories: 2250,
                        estimatedAt: ExpenditureEstimateSyncingTests.estimatedAt,
                        initialSource: nil),
                ])
        }

        @Test("同じ推定が届き直すと、行を増やさずその値にそろえること")
        func overwritesWithArrivedValue() throws {
            try syncing.apply(
                [
                    .expenditureEstimate(
                        ExpenditureEstimateSyncingTests.synced(
                            id: initialId, expenditureKilocalories: 2400, initialSource: .formula))
                ], to: cache)

            let initial = try #require(cache.all().first { $0.id == initialId })
            #expect(cache.all().count == 2)
            #expect(initial.expenditureKilocalories == 2400)
            #expect(initial.initialSource == .formula)
        }

        @Test("当てる始まりの日が読めない推定は、キャッシュに入れないこと")
        func skipsUnreadableEffectiveDay() throws {
            try syncing.apply(
                [
                    .expenditureEstimate(
                        ExpenditureEstimateSyncingTests.synced(id: UUID(), effectiveOn: "先週"))
                ], to: cache)

            #expect(Set(cache.all().map(\.id)) == [initialId, laterId])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.mealDeletion(mealId: initialId)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、推定がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
