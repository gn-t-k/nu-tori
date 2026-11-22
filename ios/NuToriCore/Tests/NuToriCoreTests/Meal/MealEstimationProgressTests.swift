import Foundation
import NuToriCore
import Testing

@Suite("推定を待っていた食事の推定が済んだか")
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

        @Test("推定できたら、済んだとすること")
        func estimated() {
            #expect(
                MealEstimationProgressTests.progress(meal, .estimated).hasFinished(since: earlier))
        }

        @Test("推定できなかったら、済んだとしないこと")
        func failed() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .failed).hasFinished(since: earlier))
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

        @Test("推定できたら、済んだとすること")
        func estimated() {
            #expect(
                MealEstimationProgressTests.progress(meal, .estimated).hasFinished(since: earlier))
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

        @Test("推定できた形で届いても、済んだとしないこと")
        func estimated() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .estimated).hasFinished(since: earlier))
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

        @Test("推定できたままなら、済んだとしないこと")
        func staysEstimated() {
            #expect(
                !MealEstimationProgressTests.progress(meal, .estimated).hasFinished(since: earlier))
        }
    }
}
