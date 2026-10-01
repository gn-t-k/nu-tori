import Foundation
import NuToriCore
import Testing

@Suite("1日の食べた量")
struct DayFoodTests {
    /// P 10 g・F 10 g・C 17.5 g。P×4 : F×9 : C×4 = 40 : 90 : 70 で、割合は 0.2・0.45・0.35
    static let lunchNutrients: [Nutrient: Double] = [
        .energyKcal: 520, .proteinG: 10, .fatG: 10, .carbohydrateG: 17.5,
    ]

    @Suite("食事の無い日")
    struct NoMeals {
        @Test("食事と栄養のまとまりを出さないこと")
        func hasNoMeals() {
            #expect(DayFood(meals: []) == .noMeals)
        }
    }

    @Suite("推定できた食事だけの日")
    struct OnlyEstimated {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: .estimated, nutrients: DayFoodTests.lunchNutrients),
                try .fixture(
                    status: .estimated,
                    nutrients: [.energyKcal: 80, .proteinG: 0, .fatG: 0, .carbohydrateG: 0]),
            ])
        }

        @Test("食事の合計を足した値を持ち、お知らせは付けないこと")
        func sumsMeals() throws {
            let figures = try #require(food.figures)

            #expect(figures.totals[.energyKcal] == .exactly(600))
            #expect(figures.totals[.proteinG] == .exactly(10))
            #expect(figures.pendingMealCount == 0)
        }

        @Test("P・F・C の割合を、P×4 : F×9 : C×4 の比で出すこと")
        func sharesRingByEnergyRatio() throws {
            let shares = try #require(food.figures?.shares)

            #expect(shares == PFCShares(protein: 0.2, fat: 0.45, carbohydrate: 0.35))
        }

        @Test("丸を塗り、記録の続き具合に入ること")
        func paintsRing() {
            let ring = DayRing(hasWeightRecord: false, food: food)

            #expect(ring.shares == PFCShares(protein: 0.2, fat: 0.45, carbohydrate: 0.35))
            #expect(ring.hasRecordedFood)
        }
    }

    @Suite("「不明」の材料が混じる栄養があるとき")
    struct WithUnknownNutrient {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: .estimated, nutrients: [.energyKcal: 300, .proteinG: 12]),
                try .fixture(status: .estimated, nutrients: [.energyKcal: 200]),
            ])
        }

        @Test("その栄養の合計に「以上」が付くこと")
        func totalIsAtLeast() throws {
            let figures = try #require(food.figures)

            #expect(figures.totals[.energyKcal] == .exactly(500))
            #expect(figures.totals[.proteinG] == .atLeast(12))
        }
    }

    @Suite("kcal はあるが P・F・C がすべて 0 の日")
    struct AllZeroMacros {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(
                    status: .estimated,
                    nutrients: [.energyKcal: 5, .proteinG: 0, .fatG: 0, .carbohydrateG: 0])
            ])
        }

        @Test("kcal を持ち、割合は持たないこと")
        func hasKilocaloriesWithoutShares() throws {
            let figures = try #require(food.figures)

            #expect(figures.totals[.energyKcal] == .exactly(5))
            #expect(figures.shares == nil)
        }

        @Test("丸を塗らず、記録の続き具合に入らないこと")
        func doesNotPaintRing() {
            let ring = DayRing(hasWeightRecord: false, food: food)

            #expect(ring.shares == nil)
            #expect(!ring.hasRecordedFood)
        }
    }

    @Suite("推定が済んでいない食事だけの日")
    struct OnlyPending {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: nil),
                try .fixture(status: .estimating),
                try .fixture(status: .deferredToNextDay),
                try .fixture(status: .awaitingPhotos, recordedOnThisDevice: false),
            ])
        }

        @Test("状態で書き分けず、どれも済んでいないことだけを持つこと")
        func isAllPending() {
            #expect(food == .allPending)
        }

        @Test("丸は空の輪で、記録の続き具合に入らないこと")
        func ringIsEmpty() {
            let ring = DayRing(hasWeightRecord: false, food: food)

            #expect(ring.shares == nil)
            #expect(!ring.hasRecordedFood)
        }
    }

    @Suite("推定が済んだ食事と済んでいない食事が混じる日")
    struct MixedWithPending {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: .estimated, nutrients: DayFoodTests.lunchNutrients),
                try .fixture(status: .estimating),
                try .fixture(status: nil),
            ])
        }

        @Test("済んだ食事の分だけを出し、済んでいない食事の数を持つこと")
        func showsFinishedMealsAndPendingCount() throws {
            let figures = try #require(food.figures)

            #expect(figures.totals[.energyKcal] == .exactly(520))
            #expect(figures.pendingMealCount == 2)
        }

        @Test("丸は、済んだ食事の分で塗ること")
        func paintsRingFromFinishedMeals() {
            #expect(DayRing(hasWeightRecord: false, food: food).hasRecordedFood)
        }
    }

    @Suite("料理なしと推定できなかった食事だけの日")
    struct OnlyWithoutFood {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: .noDishes), try .fixture(status: .failed),
            ])
        }

        @Test("出せなかった日として、済んでいない食事は 0 と持つこと")
        func isUnavailable() {
            #expect(food == .unavailable(pendingMealCount: 0))
        }

        @Test("丸は空の輪で、記録の続き具合に入らないこと")
        func ringIsEmpty() {
            let ring = DayRing(hasWeightRecord: false, food: food)

            #expect(ring.shares == nil)
            #expect(!ring.hasRecordedFood)
        }
    }

    @Suite("料理なしと推定できなかった食事と、推定が済んでいない食事だけの日")
    struct WithoutFoodAndPending {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: .noDishes), try .fixture(status: .estimating),
            ])
        }

        @Test("kcal のある食事が無いので、「—」にして、済んでいない食事の数を持つこと")
        func isUnavailableWithPendingCount() {
            #expect(food == .unavailable(pendingMealCount: 1))
        }
    }

    @Suite("料理なしの食事と、推定できた食事が混じる日")
    struct WithoutFoodAndEstimated {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: .estimated, nutrients: DayFoodTests.lunchNutrients),
                try .fixture(status: .failed),
            ])
        }

        @Test("料理なしの食事は合計にも注記にも影響しないこと")
        func ignoresMealsWithoutFood() throws {
            let figures = try #require(food.figures)

            #expect(figures.totals[.energyKcal] == .exactly(520))
            #expect(figures.pendingMealCount == 0)
        }
    }

    @Suite("推定できたのに kcal を持つ材料が1つも無い日")
    struct EstimatedWithoutKilocalories {
        let food: DayFood

        init() throws {
            food = DayFood(meals: [
                try .fixture(status: .estimated, nutrients: [.proteinG: 10])
            ])
        }

        @Test("kcal が出せない日として扱うこと")
        func isUnavailable() {
            #expect(food == .unavailable(pendingMealCount: 0))
        }
    }

    @Suite("日のまとめに添える文")
    struct Note {
        static let ringNote = "目標がないので、丸は P・F・C の割合で一周します。"

        @Suite("推定が済んだ食事だけの日")
        struct OnlyEstimated {
            let food: DayFood

            init() throws {
                food = DayFood(meals: [
                    try .fixture(status: .estimated, nutrients: DayFoodTests.lunchNutrients)
                ])
            }

            @Test("丸の説明だけを添えること")
            func onlyRingNote() {
                #expect(food.notes == [Note.ringNote])
            }
        }

        @Suite("どれも済んでいない日")
        struct AllPending {
            let food = DayFood.allPending

            @Test("推定しているところだと添えること")
            func saysEstimating() {
                #expect(
                    food.notes == [
                        Note.ringNote,
                        "この日の食事は、まだ料理と栄養を推定しているところです。推定が済むと、ここに kcal と P・F・C が出ます。",
                    ])
            }
        }

        @Suite("一部が済んでいない日")
        struct SomePending {
            let food: DayFood

            init() throws {
                food = DayFood(meals: [
                    try .fixture(status: .estimated, nutrients: DayFoodTests.lunchNutrients),
                    try .fixture(status: .estimating),
                    try .fixture(status: .deferredToNextDay),
                ])
            }

            @Test("済んでいない食事の数を添えること")
            func countsPendingMeals() {
                #expect(
                    food.notes == [
                        Note.ringNote,
                        "まだ推定が済んでいない食事が2つあります。推定が済むと、その食事の kcal と P・F・C も、この合計に足されます。",
                    ])
            }
        }

        @Suite("kcal が出ず、済んでいない食事がある日")
        struct UnavailableWithPending {
            let food = DayFood.unavailable(pendingMealCount: 1)

            @Test("済んでいない食事の数を添えること")
            func countsPendingMeals() {
                #expect(
                    food.notes == [
                        Note.ringNote,
                        "まだ推定が済んでいない食事が1つあります。推定が済むと、その食事の kcal と P・F・C も、この合計に足されます。",
                    ])
            }
        }

        @Suite("料理なしと推定できなかった食事だけの日")
        struct Unavailable {
            let food = DayFood.unavailable(pendingMealCount: 0)

            @Test("出せなかったと添えること")
            func saysUnavailable() {
                #expect(
                    food.notes == [
                        Note.ringNote, "この日の食事からは、kcal と P・F・C を出せませんでした。",
                    ])
            }
        }

        @Suite("食事の無い日")
        struct NoMeals {
            let food = DayFood.noMeals

            @Test("何も添えないこと")
            func addsNothing() {
                #expect(food.notes.isEmpty)
            }
        }
    }
}
