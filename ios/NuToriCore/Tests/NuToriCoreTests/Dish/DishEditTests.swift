import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("料理を直す")
struct DishEditTests {
    static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let riceId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e1")!
    static let chickenId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e2")!

    @Suite("推定したままの料理の量を直したとき")
    struct CorrectingQuantity {
        let edited: DishEdit?

        init() {
            let dish = Dish.fixture(
                id: DishEditTests.dishId,
                quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated))
            edited = DishEdit.correctingQuantity(
                of: dish,
                ingredients: [
                    .fixture(
                        id: DishEditTests.riceId, dishId: DishEditTests.dishId, name: "ご飯",
                        quantity: 200),
                    .fixture(
                        id: DishEditTests.chickenId, dishId: DishEditTests.dishId,
                        name: "鶏もも肉", quantity: 80, quantitySource: .corrected),
                    .fixture(dishId: UUID(), name: "ほかの料理の材料", quantity: 50),
                ],
                to: 1.5)
        }

        @Test("料理の量を直した量にし、出どころを「直した」にすること")
        func correctsDishQuantity() throws {
            let edited = try #require(edited)

            #expect(
                edited.dish.quantity == Dish.Quantity(value: 1.5, unit: "杯", source: .corrected))
        }

        @Test("その料理の材料の量を同じ割合で変え、材料の出どころは変えないこと")
        func proportionsIngredients() throws {
            let edited = try #require(edited)

            #expect(
                edited.ingredients.map(\.id) == [DishEditTests.riceId, DishEditTests.chickenId])
            #expect(edited.ingredients.map(\.quantity) == [300, 120])
            #expect(edited.ingredients.map(\.quantitySource) == [.estimated, .corrected])
        }

        @Test("名前と、直した量と比例させた材料の量を載せた書き込み1つにすること")
        func makesOneCorrection() throws {
            let edited = try #require(edited)

            #expect(
                edited.correction
                    == DishCorrection(
                        id: DishEditTests.dishId, name: "親子丼",
                        quantity: .init(
                            value: 1.5,
                            proportionedIngredients: [
                                .init(ingredientId: DishEditTests.riceId, quantity: 300),
                                .init(ingredientId: DishEditTests.chickenId, quantity: 120),
                            ])))
        }
    }

    @Suite("料理の量を、受け付ける範囲の外の 0 に直したとき")
    struct CorrectingQuantityToZero {
        let edited: DishEdit?

        init() {
            edited = DishEdit.correctingQuantity(
                of: Dish.fixture(quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated)),
                ingredients: [], to: 0)
        }

        @Test("直さないこと")
        func ignores() {
            #expect(edited == nil)
        }
    }

    @Suite("料理の量を、今と同じ量に直したとき")
    struct CorrectingQuantityToSame {
        let edited: DishEdit?

        init() {
            edited = DishEdit.correctingQuantity(
                of: Dish.fixture(quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated)),
                ingredients: [], to: 1)
        }

        @Test("直さないこと")
        func ignores() {
            #expect(edited == nil)
        }
    }

    @Suite("量の無い料理の量を直そうとしたとき")
    struct CorrectingQuantityOfDishWithoutQuantity {
        let edited: DishEdit?

        init() {
            edited = DishEdit.correctingQuantity(
                of: .fixture(quantity: nil), ingredients: [], to: 1)
        }

        @Test("直さないこと")
        func ignores() {
            #expect(edited == nil)
        }
    }

    @Suite("量のある料理の名前を直したとき")
    struct RenamingDishWithQuantity {
        let edited: DishEdit?

        init() {
            let dish = Dish.fixture(
                id: DishEditTests.dishId,
                quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .corrected))
            edited = DishEdit.renaming(dish, to: "  カツカレー \n")
        }

        @Test("前後の空白を除いた名前にし、量と材料は変えないこと")
        func renamesOnly() throws {
            let edited = try #require(edited)

            #expect(edited.dish.name == "カツカレー")
            #expect(
                edited.dish.quantity == Dish.Quantity(value: 1.5, unit: "杯", source: .corrected))
            #expect(edited.ingredients.isEmpty)
        }

        // 量を載せると、推定し直しで材料が入れ替わったあとに届いた名前の直しが受け付けられなくなる
        @Test("量と比例の材料を省き、名前だけを運ぶ書き込みにすること")
        func carriesNameOnly() throws {
            let edited = try #require(edited)

            #expect(
                edited.correction
                    == DishCorrection(id: DishEditTests.dishId, name: "カツカレー", quantity: nil))
        }
    }

    @Suite("量の無い料理の名前を直したとき")
    struct RenamingDishWithoutQuantity {
        let edited: DishEdit?

        init() {
            edited = DishEdit.renaming(.fixture(id: DishEditTests.dishId, quantity: nil), to: "豚汁")
        }

        @Test("量と比例の材料を省き、名前だけを運ぶ書き込みにすること")
        func carriesNameOnly() throws {
            let edited = try #require(edited)

            #expect(
                edited.correction
                    == DishCorrection(id: DishEditTests.dishId, name: "豚汁", quantity: nil))
        }
    }

    @Suite("料理の名前を、前後の空白を除いて空の名前に直したとき")
    struct RenamingToBlank {
        let edited: DishEdit?

        init() {
            edited = DishEdit.renaming(Dish.fixture(name: "親子丼"), to: " \n ")
        }

        @Test("直さないこと")
        func ignores() {
            #expect(edited == nil)
        }
    }

    @Suite("料理の名前を、前後の空白を除いて今と同じ名前に直したとき")
    struct RenamingToSame {
        let edited: DishEdit?

        init() {
            edited = DishEdit.renaming(Dish.fixture(name: "親子丼"), to: "親子丼 ")
        }

        @Test("直さないこと")
        func ignores() {
            #expect(edited == nil)
        }
    }
}
