import Foundation
import NuToriCore
import Testing

@Suite("食事の栄養の見せ方")
struct MealNutritionTests {
    static let nutrients: [Nutrient: Double] = [.energyKcal: 500]

    @Suite("送った端末で、推定の状態がまだ届いていない食事")
    struct NotSent {
        let card: MealCard

        init() throws {
            card = try .fixture(status: nil, nutrients: MealNutritionTests.nutrients)
        }

        @Test("まだ合計を出せないこと")
        func isPending() {
            #expect(card.nutrition == .pending)
        }
    }

    @Suite("ほかの端末で、推定の状態がまだ届いていない食事")
    struct NotArrivedOnOtherDevice {
        let card: MealCard

        init() throws {
            card = try .fixture(
                status: nil, nutrients: MealNutritionTests.nutrients, recordedOnThisDevice: false)
        }

        @Test("まだ合計を出せないこと")
        func isPending() {
            #expect(card.nutrition == .pending)
        }
    }

    @Suite("写真を待っている食事")
    struct AwaitingPhotos {
        let card: MealCard

        init() throws {
            card = try .fixture(status: .awaitingPhotos, nutrients: MealNutritionTests.nutrients)
        }

        @Test("まだ合計を出せないこと")
        func isPending() {
            #expect(card.nutrition == .pending)
        }
    }

    @Suite("推定中の食事")
    struct Estimating {
        let card: MealCard

        init() throws {
            card = try .fixture(status: .estimating, nutrients: MealNutritionTests.nutrients)
        }

        @Test("まだ合計を出せないこと")
        func isPending() {
            #expect(card.nutrition == .pending)
        }
    }

    @Suite("翌日に推定する食事")
    struct DeferredToNextDay {
        let card: MealCard

        init() throws {
            card = try .fixture(
                status: .deferredToNextDay, nutrients: MealNutritionTests.nutrients)
        }

        @Test("まだ合計を出せないこと")
        func isPending() {
            #expect(card.nutrition == .pending)
        }
    }

    @Suite("推定できた食事")
    struct Estimated {
        let card: MealCard

        init() throws {
            card = try .fixture(status: .estimated, nutrients: [.energyKcal: 500, .proteinG: 20])
        }

        @Test("料理と材料から出した合計を持つこと")
        func hasTotals() {
            #expect(card.nutrition == .estimated(card.contents.totals))
            #expect(card.contents.totals[.energyKcal] == .exactly(500))
        }
    }

    @Suite("推定できたのに料理がまだ届いていない食事")
    struct EstimatedWithoutDishes {
        let card: MealCard

        init() throws {
            card = try .fixture(status: .estimated)
        }

        @Test("済んでいないものとして扱うこと")
        func isPending() {
            #expect(card.nutrition == .pending)
        }
    }

    @Suite("料理なしの食事")
    struct NoDishes {
        let card: MealCard

        init() throws {
            card = try .fixture(status: .noDishes)
        }

        @Test("合計は 0 kcal で、日の丸には数えないこと")
        func hasNoFood() {
            #expect(card.nutrition == .noFood)
        }
    }

    @Suite("推定できなかった食事")
    struct Failed {
        let card: MealCard

        init() throws {
            card = try .fixture(status: .failed)
        }

        @Test("合計は 0 kcal で、日の丸には数えないこと")
        func hasNoFood() {
            #expect(card.nutrition == .noFood)
        }
    }
}
