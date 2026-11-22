import Foundation
import NuToriCore
import Testing

@Suite("推定を待っていた食事の結果が出たか")
struct MealEstimationProgressTests {
    static func progress(_ meal: Meal, _ status: MealEstimationStatus?) -> MealEstimationProgress {
        MealEstimationProgress(meals: [
            MealCard(meal: meal, status: status, recordedOnThisDevice: true)
        ])
    }

    @Suite("推定中だった食事")
    struct WasEstimating {
        let meal: Meal
        let earlier: MealEstimationProgress

        init() throws {
            meal = try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            earlier = MealEstimationProgressTests.progress(meal, .estimating)
        }

        @Test("推定できたら、推定できたとすること")
        func estimated() {
            #expect(
                MealEstimationProgressTests.progress(meal, .estimated).hasEstimated(since: earlier))
        }

        @Test("推定できなかったら、推定できたとしないこと")
        func failed() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .failed).hasEstimated(since: earlier))
        }

        @Test("推定できなかったら、推定できなかったとすること")
        func failedIsFailure() {
            #expect(MealEstimationProgressTests.progress(meal, .failed).hasFailed(since: earlier))
        }

        @Test("料理が見つからなかったら、料理が見つからなかったとすること")
        func noDishes() {
            #expect(
                MealEstimationProgressTests.progress(meal, .noDishes)
                    .hasFoundNoDishes(since: earlier))
        }

        @Test("料理が見つからなかったら、推定できなかったとしないこと")
        func noDishesIsNotFailure() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .noDishes).hasFailed(since: earlier))
        }

        @Test("推定できたら、推定できなかったとも料理が見つからなかったともしないこと")
        func estimatedIsNeither() {
            let later = MealEstimationProgressTests.progress(meal, .estimated)
            #expect(!later.hasFailed(since: earlier))
            #expect(!later.hasFoundNoDishes(since: earlier))
        }
    }

    @Suite("まだ送れていなかった食事")
    struct WasNotSent {
        let meal: Meal
        let earlier: MealEstimationProgress

        init() throws {
            meal = try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            earlier = MealEstimationProgressTests.progress(meal, nil)
        }

        @Test("推定できたら、推定できたとすること")
        func estimated() {
            #expect(
                MealEstimationProgressTests.progress(meal, .estimated).hasEstimated(since: earlier))
        }
    }

    @Suite("前に無かった食事")
    struct WasAbsent {
        let meal: Meal
        let earlier: MealEstimationProgress

        init() throws {
            meal = try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            earlier = MealEstimationProgress(meals: [])
        }

        @Test("推定できた形で届いても、推定できたとしないこと")
        func estimated() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .estimated).hasEstimated(since: earlier)
            )
        }

        @Test("推定できなかった形で届いても、推定できなかったとしないこと")
        func failed() {
            #expect(!MealEstimationProgressTests.progress(meal, .failed).hasFailed(since: earlier))
        }

        @Test("料理が見つからなかった形で届いても、料理が見つからなかったとしないこと")
        func noDishes() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .noDishes)
                    .hasFoundNoDishes(since: earlier))
        }
    }

    @Suite("推定できていた食事")
    struct WasEstimated {
        let meal: Meal
        let earlier: MealEstimationProgress

        init() throws {
            meal = try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            earlier = MealEstimationProgressTests.progress(meal, .estimated)
        }

        @Test("推定できたままなら、推定できたとしないこと")
        func staysEstimated() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .estimated).hasEstimated(since: earlier)
            )
        }
    }
}
