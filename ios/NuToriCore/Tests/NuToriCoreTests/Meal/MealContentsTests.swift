import Foundation
import NuToriCore
import Testing

@Suite("食事の料理と材料")
struct MealContentsTests {
    static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
    static let dishA = UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!
    static let dishB = UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")!
    static let dishC = UUID(uuidString: "00000000-0000-4000-8000-0000000000a3")!

    @Suite("取りに行った料理と材料を食事に集めるとき")
    struct Gathering {
        let contents: MealContents

        init() {
            let otherMeal = UUID()
            contents = MealContents(
                mealId: MealContentsTests.mealId,
                dishes: [
                    // 並び順が同じなら ID の順
                    .fixture(
                        id: MealContentsTests.dishB, mealId: MealContentsTests.mealId, name: "味噌汁",
                        positionInMeal: 1),
                    .fixture(
                        id: MealContentsTests.dishA, mealId: MealContentsTests.mealId, name: "親子丼",
                        positionInMeal: 1),
                    .fixture(
                        id: MealContentsTests.dishC, mealId: MealContentsTests.mealId, name: "サラダ",
                        positionInMeal: 0),
                    .fixture(mealId: otherMeal, name: "ほかの食事の料理"),
                ],
                ingredients: [
                    .fixture(
                        dishId: MealContentsTests.dishA, name: "卵", positionInDish: 1,
                        nutrients: [.energyKcal: 100]),
                    .fixture(
                        dishId: MealContentsTests.dishA, name: "鶏肉", positionInDish: 0,
                        nutrients: [.energyKcal: 200]),
                    .fixture(dishId: UUID(), name: "親の料理がまだ届いていない材料"),
                ]
            )
        }

        @Test("カードの名前は、料理の名前を並び順に「・」でつなぐこと")
        func joinsDishNames() {
            #expect(contents.name == "サラダ・親子丼・味噌汁")
        }

        @Test("この食事の料理だけを、並び順（同じなら ID の順）で並べること")
        func ordersDishesOfMeal() {
            #expect(contents.dishes.map(\.dish.name) == ["サラダ", "親子丼", "味噌汁"])
        }

        @Test("料理の材料を、並び順で並べ、親の料理がまだ届いていない材料は出さないこと")
        func ordersIngredientsOfDish() {
            #expect(contents.dishes[1].ingredients.map(\.name) == ["鶏肉", "卵"])
            #expect(contents.dishes.flatMap(\.ingredients).count == 2)
        }

        @Test("料理ごとの合計と、食事の合計を出すこと")
        func totalsPerDishAndMeal() {
            #expect(contents.dishes[1].totals[.energyKcal] == .exactly(300))
            #expect(contents.dishes[0].totals[.energyKcal] == .exactly(0))
            #expect(contents.totals[.energyKcal] == .exactly(300))
        }
    }

    @Suite("栄養の出どころの1行")
    struct SourceLine {
        @Suite("栄養成分表示・成分表・推定の材料が混じる食事")
        struct MixedSources {
            let contents: MealContents

            init() {
                contents = MealContents(
                    mealId: MealContentsTests.mealId,
                    dishes: [
                        .fixture(id: MealContentsTests.dishA, mealId: MealContentsTests.mealId)
                    ],
                    ingredients: [
                        .fixture(dishId: MealContentsTests.dishA, nutrientSource: .estimated),
                        .fixture(
                            dishId: MealContentsTests.dishA,
                            nutrientSource: .foodComposition(foodNumber: "11225")),
                        .fixture(
                            dishId: MealContentsTests.dishA,
                            nutrientSource: .foodComposition(foodNumber: "01088")),
                        .fixture(
                            dishId: MealContentsTests.dishA,
                            nutrientSource: .nutritionLabel(basisGrams: 250)),
                    ])
            }

            @Test("栄養成分表示・成分表・推定の順に材料の数を並べ、0 のものは書かないこと")
            func listsCountsInOrder() throws {
                let line = try #require(contents.nutrientSourceLine)

                #expect(
                    line.entries == [
                        .init(kind: .nutritionLabel, count: 1),
                        .init(kind: .foodComposition, count: 2),
                        .init(kind: .estimated, count: 1),
                    ])
                #expect(line.showsCounts)
            }
        }

        @Suite("成分表の材料だけの食事")
        struct SingleSource {
            let contents: MealContents

            init() {
                contents = MealContents(
                    mealId: MealContentsTests.mealId,
                    dishes: [
                        .fixture(id: MealContentsTests.dishA, mealId: MealContentsTests.mealId)
                    ],
                    ingredients: [
                        .fixture(
                            dishId: MealContentsTests.dishA,
                            nutrientSource: .foodComposition(foodNumber: "11225")),
                        .fixture(
                            dishId: MealContentsTests.dishA,
                            nutrientSource: .foodComposition(foodNumber: "01088")),
                    ])
            }

            @Test("数を書かないこと")
            func hidesCounts() throws {
                let line = try #require(contents.nutrientSourceLine)

                #expect(line.entries == [.init(kind: .foodComposition, count: 2)])
                #expect(!line.showsCounts)
            }
        }

        @Suite("材料が無い食事")
        struct WithoutIngredients {
            let contents = MealContents(
                mealId: MealContentsTests.mealId, dishes: [], ingredients: [])

            @Test("1行を出さないこと")
            func hasNoLine() {
                #expect(contents.nutrientSourceLine == nil)
            }
        }
    }

    @Suite("栄養の出典")
    struct Citation {
        @Suite("成分表を使った材料が1つでもある食事")
        struct WithFoodComposition {
            let contents: MealContents

            init() {
                contents = MealContents(
                    mealId: MealContentsTests.mealId,
                    dishes: [
                        .fixture(id: MealContentsTests.dishA, mealId: MealContentsTests.mealId)
                    ],
                    ingredients: [
                        .fixture(dishId: MealContentsTests.dishA, nutrientSource: .estimated),
                        .fixture(
                            dishId: MealContentsTests.dishA,
                            nutrientSource: .foodComposition(foodNumber: "11225")),
                    ])
            }

            @Test("出すこと")
            func shows() {
                #expect(contents.showsNutrientCitation)
            }
        }

        @Suite("成分表を使った材料が1つも無い食事")
        struct WithoutFoodComposition {
            let contents: MealContents

            init() {
                contents = MealContents(
                    mealId: MealContentsTests.mealId,
                    dishes: [
                        .fixture(id: MealContentsTests.dishA, mealId: MealContentsTests.mealId)
                    ],
                    ingredients: [
                        .fixture(dishId: MealContentsTests.dishA, nutrientSource: .estimated),
                        .fixture(
                            dishId: MealContentsTests.dishA,
                            nutrientSource: .nutritionLabel(basisGrams: 250)),
                    ])
            }

            @Test("出さないこと")
            func hides() {
                #expect(!contents.showsNutrientCitation)
            }
        }
    }

    @Suite("料理がまだ無い食事")
    struct WithoutDishes {
        let contents = MealContents(mealId: MealContentsTests.mealId, dishes: [], ingredients: [])

        @Test("カードの名前を持たないこと")
        func hasNoName() {
            #expect(contents.name == nil)
        }
    }
}
