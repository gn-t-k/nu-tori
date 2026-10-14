import Foundation
import NuToriCore
import Testing

@Suite("1日の丸")
struct DayRingTests {
    /// 1日の目安 1,850 kcal
    static let guide = DailyGuide(
        id: UUID(), goalId: UUID(), expenditureEstimateId: UUID(),
        effectiveDay: CalendarDay(year: 2026, month: 10, day: 6), energyKilocalories: 1850,
        proteinGrams: 130, fatGrams: 50, carbohydrateGrams: 220, limitHits: [])

    /// P 10 g・F 10 g・C 17.5 g。P×4 : F×9 : C×4 = 40 : 90 : 70 で、割合は 0.2・0.45・0.35
    static func food(kilocalories: Double) throws -> DayFood {
        DayFood(meals: [
            try .fixture(
                status: .estimated,
                nutrients: [
                    .energyKcal: kilocalories, .proteinG: 10, .fatG: 10, .carbohydrateG: 17.5,
                ])
        ])
    }

    @Suite("1日の目安と比べる日")
    struct ComparedWithGuide {
        @Test("一周を1日の目安にして、食べた kcal の分だけ P・F・C の割合で進むこと")
        func fillsEatenPartOfGuide() throws {
            let ring = DayRing(
                hasWeightRecord: false, food: try DayRingTests.food(kilocalories: 925),
                dailyGuide: DayRingTests.guide)

            #expect(ring.arcs == DayRing.Arcs(protein: 0.1, fat: 0.225, carbohydrate: 0.175))
            #expect(!ring.exceedsDailyGuide)
        }

        @Test("目安を超えたら、一周で止めて、超えた印を付けること")
        func stopsAtFullCircleWhenExceeded() throws {
            let ring = DayRing(
                hasWeightRecord: false, food: try DayRingTests.food(kilocalories: 2000),
                dailyGuide: DayRingTests.guide)

            #expect(ring.arcs == DayRing.Arcs(protein: 0.2, fat: 0.45, carbohydrate: 0.35))
            #expect(ring.exceedsDailyGuide)
        }

        @Test("目安ちょうどでは、超えた印を付けないこと")
        func doesNotMarkExactGuide() throws {
            let ring = DayRing(
                hasWeightRecord: false, food: try DayRingTests.food(kilocalories: 1850),
                dailyGuide: DayRingTests.guide)

            #expect(!ring.exceedsDailyGuide)
        }

        @Test("食べた量の下の文に、目標がないことを書かないこと")
        func omitsNoGoalNote() throws {
            let food = try DayRingTests.food(kilocalories: 925)

            #expect(food.notes(comparingWith: DayRingTests.guide).isEmpty)
        }
    }

    @Suite("1日の目安と比べない日（目標を立てる前の日）")
    struct NotCompared {
        @Test("今の形のまま、P・F・C の割合で一周し、超えた印を付けないこと")
        func fillsWholeCircleByShares() throws {
            let ring = DayRing(
                hasWeightRecord: false, food: try DayRingTests.food(kilocalories: 2000))

            #expect(ring.arcs == DayRing.Arcs(protein: 0.2, fat: 0.45, carbohydrate: 0.35))
            #expect(!ring.exceedsDailyGuide)
        }

        @Test("食べた量の下の文は、今のまま目標がないことを書くこと")
        func keepsNoGoalNote() throws {
            let food = try DayRingTests.food(kilocalories: 925)

            #expect(food.notes(comparingWith: nil) == food.notes)
            #expect(food.notes == ["目標がないので、丸は P・F・C の割合で一周します。"])
        }
    }

    @Suite("推定が済んだ食事の無い日")
    struct NoFigures {
        @Test("目安があっても空の輪にすること")
        func isEmpty() {
            let ring = DayRing(
                hasWeightRecord: false, food: .noMeals, dailyGuide: DayRingTests.guide)

            #expect(ring.arcs == nil)
            #expect(!ring.exceedsDailyGuide)
        }
    }
}
