import Foundation
import NuToriCore
import Testing

@Suite("ヘルスケアに書く食品の組")
struct HealthNutritionWriteTests {
    @Suite("料理の合計から作るとき")
    struct FromDish {
        let meal: Meal
        let dish: Dish

        init() throws {
            meal = try Meal.fixture(
                eatenAt: "2026-09-22T12:10:00+09:00", sentAt: "2026-09-22T12:11:00+09:00")
            dish = Dish(
                id: UUID(), mealId: meal.id, name: "親子丼",
                quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated),
                positionInMeal: 0, version: 3)
        }

        @Test("食品名を料理の名前、時刻を食事の撮った時刻、同期 ID と版を料理の ID と版にすること")
        func usesDishAndMeal() throws {
            let write = try #require(
                HealthNutritionWrite(
                    dish: contents([.energyKcal: 200]), of: meal, authorized: [.energy]))

            #expect(write.foodName == "親子丼")
            #expect(write.instant == meal.eatenAt)
            #expect(write.syncId == dish.id)
            #expect(write.syncVersion == 3)
        }

        @Test("時間帯の名前を、食事の時差から作ること")
        func namesTimeZoneFromMealOffset() throws {
            let write = try #require(
                HealthNutritionWrite(
                    dish: contents([.energyKcal: 200]), of: meal, authorized: [.energy]))

            #expect(write.timeZoneName == "GMT+0900")
        }

        @Test("値は、料理の材料の合計と同じにすること")
        func writesDishTotals() throws {
            let write = try #require(
                HealthNutritionWrite(
                    dish: contents([.energyKcal: 150, .proteinG: 12.5], quantity: 200), of: meal,
                    authorized: [.energy, .protein]))

            #expect(
                write.values == [
                    .init(nutrient: .energy, amount: 300),
                    .init(nutrient: .protein, amount: 25),
                ])
        }

        @Test("食塩相当量を、ナトリウムに換算して書くこと")
        func convertsSaltToSodium() throws {
            let write = try #require(
                HealthNutritionWrite(
                    dish: contents([.saltEquivalentG: 2.54]), of: meal, authorized: [.sodium]))

            let value = try #require(write.values.first)
            #expect(write.values.count == 1)
            #expect(value.nutrient == .sodium)
            #expect(abs(value.amount - 1000) < 1e-9)
        }

        @Test("「不明」の栄養は書かないこと")
        func skipsUnknownNutrients() throws {
            let write = try #require(
                HealthNutritionWrite(
                    dish: contents([.energyKcal: 200]), of: meal,
                    authorized: [.energy, .protein]))

            #expect(write.values.map(\.nutrient) == [.energy])
        }

        @Test("「以上」の栄養は、分かる分の値で書くこと")
        func writesLowerBoundValue() throws {
            let known = Ingredient.fixture(dishId: dish.id, nutrients: [.proteinG: 10])
            let unknown = Ingredient.fixture(dishId: dish.id, nutrients: [:])
            let write = try #require(
                HealthNutritionWrite(
                    dish: DishContents(dish: dish, ingredients: [known, unknown]), of: meal,
                    authorized: [.protein]))

            #expect(write.values == [.init(nutrient: .protein, amount: 10)])
        }

        @Test("書き込みを許可された種類だけで組を作ること")
        func usesAuthorizedNutrientsOnly() throws {
            let write = try #require(
                HealthNutritionWrite(
                    dish: contents([.energyKcal: 200, .proteinG: 10]), of: meal,
                    authorized: [.protein]))

            #expect(write.values.map(\.nutrient) == [.protein])
        }

        @Test("水分は、材料に値があっても書かないこと")
        func doesNotWriteWater() {
            let write = HealthNutritionWrite(
                dish: contents([.waterG: 80]), of: meal, authorized: Set(HealthNutrient.allCases))

            #expect(write == nil)
        }

        @Test("書く値が1つも無いとき、組を作らないこと")
        func hasNoWriteWithoutValues() {
            let write = HealthNutritionWrite(
                dish: contents([.energyKcal: 200]), of: meal, authorized: [])

            #expect(write == nil)
        }

        private func contents(_ nutrients: [Nutrient: Double], quantity: Double = 100)
            -> DishContents
        {
            DishContents(
                dish: dish,
                ingredients: [
                    .fixture(dishId: dish.id, quantity: quantity, nutrients: nutrients)
                ])
        }
    }

    @Suite("時間帯の名前")
    struct TimeZoneName {
        @Test("東の時差を、符号と時分で書くこと")
        func namesEastOffset() {
            #expect(HealthNutritionWrite.timeZoneName(utcOffsetSeconds: 9 * 3600) == "GMT+0900")
        }

        @Test("30 分の端数のある時差を、分まで書くこと")
        func namesHalfHourOffset() {
            #expect(
                HealthNutritionWrite.timeZoneName(utcOffsetSeconds: 5 * 3600 + 1800) == "GMT+0530")
        }

        @Test("西の時差を、負の符号で書くこと")
        func namesWestOffset() {
            #expect(HealthNutritionWrite.timeZoneName(utcOffsetSeconds: -8 * 3600) == "GMT-0800")
        }

        @Test("時差が 0 のときは GMT にすること")
        func namesZeroOffset() {
            #expect(HealthNutritionWrite.timeZoneName(utcOffsetSeconds: 0) == "GMT")
        }
    }
}
