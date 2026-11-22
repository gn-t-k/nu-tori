import Foundation
import NuToriCore
import Testing

@Suite("推定を待っていた食事の推定が済んだか")
struct MealEstimationProgressTests {
    let meal: Meal

    init() throws {
        meal = try .fixture(
            eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
    }

    private func progress(_ status: MealEstimationStatus?) -> MealEstimationProgress {
        MealEstimationProgress(meals: [
            MealCard(meal: meal, status: status, recordedOnThisDevice: true)
        ])
    }

    @Test("推定中の食事が推定できたら、済んだとすること")
    func estimatingToEstimated() {
        #expect(progress(.estimated).hasFinished(since: progress(.estimating)))
    }

    @Test("まだ送れていない食事が推定できたら、済んだとすること")
    func notSentToEstimated() {
        #expect(progress(.estimated).hasFinished(since: progress(nil)))
    }

    @Test("前に無かった食事が推定できた形で届いても、済んだとしないこと")
    func appearedEstimated() {
        #expect(!progress(.estimated).hasFinished(since: MealEstimationProgress(meals: [])))
    }

    @Test("推定できなかったときは、済んだとしないこと")
    func estimatingToFailed() {
        #expect(!progress(.failed).hasFinished(since: progress(.estimating)))
    }

    @Test("推定できたままなら、済んだとしないこと")
    func staysEstimated() {
        #expect(!progress(.estimated).hasFinished(since: progress(.estimated)))
    }
}
