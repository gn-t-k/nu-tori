import Foundation
import NuToriCore
import Testing

@Suite("食事の栄養の見せ方")
struct MealNutritionTests {
    @Suite("推定が済んでいない食事")
    struct NotFinished {
        @Test("まだ送れていない・写真を待っている・推定中・翌日に推定は、まだ合計を出せないこと")
        func isPending() throws {
            let cards = [
                try MealCard.fixture(status: nil, nutrients: [.energyKcal: 500]),
                try MealCard.fixture(
                    status: nil, nutrients: [.energyKcal: 500], recordedOnThisDevice: false),
                try MealCard.fixture(status: .awaitingPhotos, nutrients: [.energyKcal: 500]),
                try MealCard.fixture(status: .estimating, nutrients: [.energyKcal: 500]),
                try MealCard.fixture(status: .deferredToNextDay, nutrients: [.energyKcal: 500]),
            ]

            #expect(cards.map(\.nutrition) == Array(repeating: .pending, count: 5))
        }
    }

    @Suite("推定できた食事")
    struct Estimated {
        @Test("料理と材料から出した合計を持つこと")
        func hasTotals() throws {
            let card = try MealCard.fixture(
                status: .estimated, nutrients: [.energyKcal: 500, .proteinG: 20])

            #expect(card.nutrition == .estimated(card.contents.totals))
            #expect(card.contents.totals[.energyKcal] == .exactly(500))
        }

        @Test("推定できたのに料理がまだ届いていなければ、済んでいないものとして扱うこと")
        func isPendingUntilDishesArrive() throws {
            let card = try MealCard.fixture(status: .estimated)

            #expect(card.nutrition == .pending)
        }
    }

    @Suite("料理なしと推定できなかった食事")
    struct WithoutFood {
        @Test("合計は 0 kcal で、日の丸には数えないこと")
        func hasNoFood() throws {
            let cards = [
                try MealCard.fixture(status: .noDishes),
                try MealCard.fixture(status: .failed),
            ]

            #expect(cards.map(\.nutrition) == [.noFood, .noFood])
        }
    }
}
