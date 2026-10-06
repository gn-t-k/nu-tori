import Foundation
import NuToriCore
import Testing

@Suite("食事の画面と料理の画面の、受け付けなかった1行の置き場")
struct MealScreenListTests {
    @Suite("食事の画面で、時刻・料理の名前を直せず、別の端末で消えていた料理があったとき")
    struct MealScreen {
        let list: MealScreenList
        let first: Dish
        let third: Dish
        let eatenAtLine: RejectedMealLine
        let nameLine: RejectedMealLine
        let goneLine: RejectedMealLine

        init() throws {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:10:00+09:00")
            first = .fixture(mealId: meal.id, name: "カレー", positionInMeal: 0)
            third = .fixture(mealId: meal.id, name: "サラダ", positionInMeal: 2)
            let card = MealCard(
                meal: meal, status: .estimated, recordedOnThisDevice: true,
                dishes: [third, first], ingredients: [])
            eatenAtLine = RejectedMealLine(
                meal: meal,
                subject: .eatenAt(
                    attempted: try Date("2026-09-24T19:40:00+09:00", strategy: .iso8601)))
            nameLine = RejectedMealLine(
                meal: meal,
                subject: .dishName(
                    .init(id: first.id, name: "カレー", positionInMeal: 0), attempted: "カツカレー"))
            goneLine = RejectedMealLine(
                meal: meal,
                subject: .goneDish(.init(id: UUID(), name: "味噌汁", positionInMeal: 1)))
            let otherMeal = try Meal.fixture(
                eatenAt: "2026-09-24T19:00:00+09:00", sentAt: "2026-09-24T19:00:00+09:00")
            list = MealScreenList(
                card: card,
                rejectedLines: [
                    .meal(goneLine), .meal(nameLine), .meal(eatenAtLine),
                    .meal(RejectedMealLine(meal: otherMeal, subject: .eatenAt(attempted: Date()))),
                ])
        }

        @Test("時刻を直せなかった1行を、時刻の下に置くこと")
        func placesEatenAtLineBelowTime() {
            #expect(list.belowEatenAt == [eatenAtLine])
        }

        @Test("名前を直せなかった1行は料理の行の下に、消えていた料理の1行はその並び順の位置に置くこと")
        func interleavesDishLines() {
            #expect(list.dishes.map(\.dish?.dish.name) == ["カレー", nil, "サラダ"])
            #expect(list.dishes.map(\.lines) == [[nameLine], [goneLine], []])
        }
    }

    @Suite("料理の画面で、材料の量を直せず、置き換わった前の材料と料理の量も直せなかったとき")
    struct DishScreen {
        let list: DishScreenList
        let rice: Ingredient
        let egg: Ingredient
        let quantityLine: RejectedMealLine
        let riceLine: RejectedMealLine
        let replacedLine: RejectedMealLine

        init() throws {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:10:00+09:00")
            let dish = Dish.fixture(mealId: meal.id, name: "親子丼")
            rice = .fixture(dishId: dish.id, name: "ご飯", positionInDish: 0)
            egg = .fixture(dishId: dish.id, name: "卵", positionInDish: 2)
            let card = MealCard(
                meal: meal, status: .estimated, recordedOnThisDevice: true, dishes: [dish],
                ingredients: [egg, rice])
            let place = RejectedMealLine.DishPlace(id: dish.id, name: "親子丼", positionInMeal: 0)
            quantityLine = RejectedMealLine(
                meal: meal, subject: .dishQuantity(place, attempted: 1.5, unit: "杯"))
            riceLine = RejectedMealLine(
                meal: meal,
                subject: .ingredientQuantity(
                    .init(id: rice.id, name: "ご飯", unit: "g", positionInDish: 0, dish: place),
                    attempted: 150))
            replacedLine = RejectedMealLine(
                meal: meal,
                subject: .replacedIngredient(
                    .init(id: UUID(), name: "玉ねぎ", unit: "g", positionInDish: 1, dish: place),
                    attempted: 30))
            let contents = try #require(card.contents.dishes.first)
            list = DishScreenList(
                contents: contents, in: card,
                rejectedLines: [.meal(replacedLine), .meal(riceLine), .meal(quantityLine)])
        }

        @Test("料理の量を直せなかった1行を、名前と量の下に置くこと")
        func placesDishLineBelowHeader() {
            #expect(list.belowHeader == [quantityLine])
        }

        @Test("材料の1行は材料の行の下に、置き換わった前の材料の1行はその並び順の位置に置くこと")
        func interleavesIngredientLines() {
            #expect(list.ingredients.map(\.ingredient?.name) == ["ご飯", nil, "卵"])
            #expect(list.ingredients.map(\.lines) == [[riceLine], [replacedLine], []])
        }
    }
}
