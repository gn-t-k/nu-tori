import Foundation
import NuToriCore
import Testing

@Suite("料理ごとの待ち")
struct MealCardDishWaitingTests {
    static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
    static let curryId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let soupId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d2")!

    /// カレー 1 皿（推定したまま。材料 1 つで 600 kcal・P 20 g・F 25 g・C 80 g）と、味噌汁 1 杯（材料 1 つで 40 kcal・P 3 g・F 1 g・C 5 g）の食事
    static func card(
        status: MealEstimationStatus? = .estimated,
        recordedOnThisDevice: Bool = true,
        soupQuantity: Dish.Quantity? = Dish.Quantity(value: 1, unit: "杯", source: .estimated),
        dishStatuses: [UUID: DishEstimationStatus] = [:],
        unsentDishIds: Set<UUID> = [],
        withCurry: Bool = true
    ) throws -> MealCard {
        let curry = Dish.fixture(
            id: curryId, mealId: mealId, name: "カレー",
            quantity: Dish.Quantity(value: 1, unit: "皿", source: .estimated), positionInMeal: 0)
        let soup = Dish.fixture(
            id: soupId, mealId: mealId, name: "味噌汁", quantity: soupQuantity, positionInMeal: 1)
        return MealCard(
            meal: try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00",
                id: mealId),
            status: status,
            recordedOnThisDevice: recordedOnThisDevice,
            dishes: withCurry ? [curry, soup] : [soup],
            ingredients: [
                .fixture(
                    dishId: curryId, name: "カレーライス",
                    nutrients: [.energyKcal: 600, .proteinG: 20, .fatG: 25, .carbohydrateG: 80]),
                .fixture(
                    dishId: soupId, name: "味噌",
                    nutrients: [.energyKcal: 40, .proteinG: 3, .fatG: 1, .carbohydrateG: 5]),
            ],
            dishEstimationStatuses: dishStatuses,
            unsentDishIds: unsentDishIds
        )
    }

    static func soup(of card: MealCard) throws -> DishContents {
        try #require(card.contents.dishes.first { $0.dish.id == soupId })
    }

    static func totals(of card: MealCard) throws -> NutrientTotals {
        try #require(card.nutrition.estimatedTotals)
    }

    @Suite("食事の画面の料理の行と、料理の画面で材料と栄養を出すか")
    struct Rows {
        @Suite("料理ごとの推定の状態が無い料理のとき")
        struct NotWaiting {
            let soup: DishContents

            init() throws {
                soup = try MealCardDishWaitingTests.soup(of: card())
            }

            @Test("量と推定の印と kcal を出し、行の下に何も置かないこと")
            func showsQuantityAndKilocalories() {
                #expect(soup.row.quantity == "1杯")
                #expect(soup.row.showsEstimateBadge)
                #expect(soup.row.kilocalories == "40 kcal")
                #expect(soup.row.note == nil)
            }

            @Test("料理の画面で材料と栄養を出すこと")
            func showsIngredients() {
                #expect(soup.showsIngredientsAndNutrients)
            }
        }

        @Suite("推定できた料理のとき")
        struct Estimated {
            let soup: DishContents

            init() throws {
                soup = try MealCardDishWaitingTests.soup(
                    of: card(dishStatuses: [soupId: .estimated]))
            }

            @Test("待っていない料理と同じに見せること")
            func showsAsNotWaiting() {
                #expect(soup.row.quantity == "1杯")
                #expect(soup.row.kilocalories == "40 kcal")
                #expect(soup.row.note == nil)
            }

            @Test("料理の画面で材料と栄養を出すこと")
            func showsIngredients() {
                #expect(soup.showsIngredientsAndNutrients)
            }
        }

        @Suite("推定中の料理のとき")
        struct Estimating {
            let soup: DishContents

            init() throws {
                soup = try MealCardDishWaitingTests.soup(
                    of: card(dishStatuses: [soupId: .estimating]))
            }

            @Test("量と kcal を「—」にし、行の下に回る印と「推定しています…」を置くこと")
            func showsEstimatingNote() {
                #expect(soup.row.quantity == "—")
                #expect(!soup.row.showsEstimateBadge)
                #expect(soup.row.kilocalories == "—")
                #expect(soup.row.note == .estimating)
                #expect(soup.row.note?.text == "推定しています…")
                #expect(soup.row.note?.showsSpinner == true)
            }

            @Test("料理の画面で材料と栄養を出さないこと")
            func hidesIngredients() {
                #expect(!soup.showsIngredientsAndNutrients)
            }
        }

        @Suite("量を直してある料理が推定中のとき")
        struct WaitingWithCorrectedQuantity {
            let row: DishRow

            init() throws {
                row = try MealCardDishWaitingTests.soup(
                    of: card(
                        soupQuantity: Dish.Quantity(value: 2, unit: "杯", source: .corrected),
                        dishStatuses: [soupId: .estimating])
                ).row
            }

            @Test("直した量を出すこと")
            func showsCorrectedQuantity() {
                #expect(row.quantity == "2杯")
                #expect(!row.showsEstimateBadge)
                #expect(row.kilocalories == "—")
            }
        }

        @Suite("翌日に推定の料理のとき")
        struct Deferred {
            let soup: DishContents

            init() throws {
                soup = try MealCardDishWaitingTests.soup(
                    of: card(dishStatuses: [soupId: .deferredToNextDay]))
            }

            @Test("行の下に「今日はもう推定できないため、明日推定します」を置くこと")
            func showsDeferredNote() {
                #expect(soup.row.quantity == "—")
                #expect(soup.row.kilocalories == "—")
                #expect(soup.row.note?.text == "今日はもう推定できないため、明日推定します")
                #expect(soup.row.note?.showsSpinner == false)
            }

            @Test("料理の画面で材料と栄養を出さないこと")
            func hidesIngredients() {
                #expect(!soup.showsIngredientsAndNutrients)
            }
        }

        @Suite("料理なしの料理のとき")
        struct NoDishes {
            let soup: DishContents

            init() throws {
                soup = try MealCardDishWaitingTests.soup(
                    of: card(dishStatuses: [soupId: .noDishes]))
            }

            @Test("前の量と 0 kcal を出し、行の下に「この名前からは材料を推定できませんでした」を置くこと")
            func showsUnestimableNote() {
                #expect(soup.row.quantity == "1杯")
                #expect(soup.row.kilocalories == "0 kcal")
                #expect(soup.row.note?.text == "この名前からは材料を推定できませんでした")
            }

            @Test("料理の画面で材料と栄養を出さないこと")
            func hidesIngredients() {
                #expect(!soup.showsIngredientsAndNutrients)
            }
        }

        @Suite("推定できなかった料理のとき")
        struct Failed {
            let soup: DishContents

            init() throws {
                soup = try MealCardDishWaitingTests.soup(of: card(dishStatuses: [soupId: .failed]))
            }

            @Test("前の量と 0 kcal を出し、行の下に「この名前からは材料を推定できませんでした」を置くこと")
            func showsUnestimableNote() {
                #expect(soup.row.quantity == "1杯")
                #expect(soup.row.kilocalories == "0 kcal")
                #expect(soup.row.note?.text == "この名前からは材料を推定できませんでした")
            }

            @Test("料理の画面で材料と栄養を出さないこと")
            func hidesIngredients() {
                #expect(!soup.showsIngredientsAndNutrients)
            }
        }

        @Suite("料理を足す・名前を直す書き込みがまだ送れていない料理のとき")
        struct Unsent {
            let row: DishRow

            init() throws {
                row = try MealCardDishWaitingTests.soup(
                    of: card(dishStatuses: [soupId: .estimated], unsentDishIds: [soupId])
                ).row
            }

            @Test("量と kcal を「—」にし、行の下に何も置かないこと")
            func showsDashes() {
                #expect(row.quantity == "—")
                #expect(row.kilocalories == "—")
                #expect(row.note == nil)
            }
        }

        @Suite("量の無い料理に推定の状態がまだ届いていないとき")
        struct AddedDishWithoutStatus {
            let row: DishRow

            init() throws {
                row = try MealCardDishWaitingTests.soup(of: card(soupQuantity: nil)).row
            }

            @Test("まだ送れていないと同じに見せること")
            func showsAsUnsent() {
                #expect(row.quantity == "—")
                #expect(row.kilocalories == "—")
                #expect(row.note == nil)
            }
        }
    }

    @Suite("「以上」")
    struct AtLeast {
        @Suite("待っている料理があるとき")
        struct WaitingDish {
            let totals: NutrientTotals

            init() throws {
                totals = try MealCardDishWaitingTests.totals(
                    of: card(dishStatuses: [soupId: .estimating]))
            }

            @Test("食事の合計は分かる料理の分だけを足し、「以上」を付けること")
            func totalsAreLowerBound() {
                #expect(totals[.energyKcal] == .atLeast(600))
                #expect(totals[.proteinG] == .atLeast(20))
                #expect(NutritionText.amount(totals[.energyKcal], of: .energyKcal) == "600 kcal 以上")
            }
        }

        @Suite("待っている料理が無いとき")
        struct NoWaitingDish {
            let totals: NutrientTotals

            init() throws {
                totals = try MealCardDishWaitingTests.totals(
                    of: card(dishStatuses: [soupId: .estimated]))
            }

            @Test("「以上」を付けないこと")
            func totalsAreExact() {
                #expect(totals[.energyKcal] == .exactly(640))
            }
        }

        @Suite("通らなかった料理があるとき")
        struct UnestimableDish {
            let totals: NutrientTotals

            init() throws {
                totals = try MealCardDishWaitingTests.totals(
                    of: card(dishStatuses: [soupId: .failed]))
            }

            @Test("通らなかった料理は 0 kcal として足し、「以上」を付けないこと")
            func countsAsZero() {
                #expect(totals[.energyKcal] == .exactly(600))
            }
        }

        @Suite("推定できた食事の料理がすべて待っているとき")
        struct AllDishesWaiting {
            let totals: NutrientTotals

            init() throws {
                totals = try MealCardDishWaitingTests.totals(
                    of: card(dishStatuses: [curryId: .estimating, soupId: .estimating]))
            }

            @Test("合計を「—」にすること")
            func showsDash() {
                #expect(NutritionText.amount(totals[.energyKcal], of: .energyKcal) == "—")
            }
        }

        @Suite("日の食事に、料理ごとに待つ食事があるとき")
        struct DayFoodWithWaitingDish {
            let food: DayFood

            init() throws {
                food = DayFood(meals: [try card(dishStatuses: [soupId: .estimating])])
            }

            @Test("日のまとめに分かる分を入れて「以上」を付け、推定が済んでいない食事に数えないこと")
            func countsKnownDishes() throws {
                let figures = try #require(food.figures)

                #expect(figures.totals[.energyKcal] == .atLeast(600))
                #expect(figures.pendingMealCount == 0)
            }
        }

        @Suite("日の食事が料理ごとに待つものだけで、分かる値が無いとき")
        struct DayFoodAllWaiting {
            let food: DayFood

            init() throws {
                food = DayFood(meals: [
                    try card(dishStatuses: [curryId: .estimating, soupId: .estimating])
                ])
            }

            @Test("推定しているところとして見せること")
            func showsAllPending() {
                #expect(food == .allPending)
            }
        }
    }

    /// 推定を待っている食事には料理を足せないので、料理があるのは、写真の推定が作った料理が食事の推定の状態より先に届いた一瞬だけ
    @Suite("推定中の食事に、写真の推定が作った料理が食事の推定の状態より先に届いたとき")
    struct DishesArrivedBeforeStatus {
        let card: MealCard

        init() throws {
            card = try MealCardDishWaitingTests.card(status: .estimating)
        }

        @Test("カードの名前の場所に、料理の名前を置かず「推定しています…」だけを置くこと")
        func showsOnlyEstimatingLine() {
            #expect(card.namePlace.dishNames == nil)
            #expect(card.namePlace.statusLine == "推定しています…")
        }

        @Test("合計を出さないこと")
        func showsNoTotals() {
            #expect(card.nutrition == .pending)
        }

        @Test("食事の画面の料理の一覧の上に推定中の1行を置くこと")
        func showsMealNote() {
            #expect(card.dishListNote == .estimating)
        }
    }

    @Suite("推定が済んだ食事に料理を足したあとの、食事のカードの名前の場所と、食事の画面の料理の一覧の上の食事の状態")
    struct AfterAdding {
        static func addedCard(_ status: MealEstimationStatus) throws -> MealCard {
            try card(status: status, dishStatuses: [soupId: .estimating], withCurry: false)
        }

        @Suite("食事が料理なしのとき")
        struct MealNoDishes {
            let card: MealCard

            init() throws {
                card = try addedCard(.noDishes)
            }

            @Test("カードの名前の場所に料理の名前を置き、状態の1行を置かないこと")
            func showsDishNames() {
                #expect(card.namePlace.dishNames == "味噌汁")
                #expect(card.namePlace.statusLine == nil)
            }

            @Test("食事の画面の料理の一覧の上に食事の状態を置かないこと")
            func hidesMealNote() {
                #expect(card.dishListNote == nil)
            }
        }

        @Suite("食事が推定できなかったとき")
        struct MealFailed {
            let card: MealCard

            init() throws {
                card = try addedCard(.failed)
            }

            @Test("カードの名前の場所に料理の名前を置き、状態の1行を置かないこと")
            func showsDishNames() {
                #expect(card.namePlace.dishNames == "味噌汁")
                #expect(card.namePlace.statusLine == nil)
            }

            @Test("食事の画面の料理の一覧の上に食事の状態を置かないこと")
            func hidesMealNote() {
                #expect(card.dishListNote == nil)
            }
        }

        @Suite("食事が推定できたとき")
        struct MealEstimated {
            let card: MealCard

            init() throws {
                card = try addedCard(.estimated)
            }

            @Test("カードの名前の場所に料理の名前を置き、状態の1行を置かないこと")
            func showsDishNames() {
                #expect(card.namePlace.dishNames == "味噌汁")
                #expect(card.namePlace.statusLine == nil)
            }

            @Test("食事の画面の料理の一覧の上に食事の状態を置かないこと")
            func hidesMealNote() {
                #expect(card.dishListNote == nil)
            }
        }

    }

    /// 料理が1つも無いあいだは、#188 のまま状態ごとの1行を置く
    @Suite("料理が1つも無い食事")
    struct WithoutDishes {
        static func cardWithoutDishes(_ status: MealEstimationStatus) throws -> MealCard {
            MealCard(
                meal: try .fixture(
                    eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00"),
                status: status, recordedOnThisDevice: true)
        }

        @Suite("推定中のとき")
        struct Estimating {
            let card: MealCard

            init() throws {
                card = try cardWithoutDishes(.estimating)
            }

            @Test("カードの名前の場所に料理の名前でなく「推定しています…」を置くこと")
            func showsStatusLine() {
                #expect(card.namePlace.dishNames == nil)
                #expect(card.namePlace.statusLine == "推定しています…")
            }

            @Test("食事の画面の料理の一覧の上に、料理を足す添え書きの無い推定中の1行を置くこと")
            func showsMealNote() {
                #expect(card.dishListNote == .estimating)
                #expect(card.dishListNote?.addDishHint == nil)
            }
        }

        @Suite("翌日に推定のとき")
        struct Deferred {
            let card: MealCard

            init() throws {
                card = try cardWithoutDishes(.deferredToNextDay)
            }

            @Test("食事の画面の料理の一覧の上に、翌日に推定の1行を置くこと")
            func showsMealNote() {
                #expect(card.dishListNote == .deferredToNextDay)
            }
        }

        @Suite("料理なしのとき")
        struct NoDishes {
            let card: MealCard

            init() throws {
                card = try cardWithoutDishes(.noDishes)
            }

            @Test("カードの名前の場所に料理の名前でなく「写真に料理が見つかりませんでした」を置くこと")
            func showsStatusLine() {
                #expect(card.namePlace.dishNames == nil)
                #expect(card.namePlace.statusLine == "写真に料理が見つかりませんでした")
            }

            @Test("食事の画面の料理の一覧の上に、料理を足す添え書きつきの料理なしの1行を置くこと")
            func showsMealNote() {
                #expect(card.dishListNote == .noDishes)
                #expect(card.dishListNote?.addDishHint == "料理の名前を入れると、量と材料を推定します。")
            }
        }

        @Suite("推定できなかったとき")
        struct Failed {
            let card: MealCard

            init() throws {
                card = try cardWithoutDishes(.failed)
            }

            @Test("食事の画面の料理の一覧の上に、推定できなかったの1行を置くこと")
            func showsMealNote() {
                #expect(card.dishListNote == .failed)
            }
        }

        @Suite("推定できたとき")
        struct Estimated {
            let card: MealCard

            init() throws {
                card = try cardWithoutDishes(.estimated)
            }

            @Test("カードの名前の場所に、料理の名前も状態の1行も置かないこと")
            func showsNothing() {
                #expect(card.namePlace.dishNames == nil)
                #expect(card.namePlace.statusLine == nil)
            }
        }
    }
}

extension MealNutrition {
    /// 分かる料理と材料から出した合計。出せない・料理なしなら nil
    fileprivate var estimatedTotals: NutrientTotals? {
        switch self {
        case .estimated(let totals): totals
        case .pending, .noFood: nil
        }
    }
}
