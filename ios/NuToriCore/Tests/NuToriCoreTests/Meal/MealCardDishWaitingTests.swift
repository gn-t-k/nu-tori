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

    static func soupRow(of card: MealCard) throws -> DishRow {
        try #require(card.contents.dishes.first { $0.dish.id == soupId }).row
    }

    static func totals(of card: MealCard) throws -> NutrientTotals {
        guard case .estimated(let totals) = card.nutrition else {
            Issue.record("合計が出ていない: \(card.nutrition)")
            throw CancellationError()
        }
        return totals
    }

    @Suite("食事の画面の料理の行")
    struct Rows {
        @Test("料理ごとの推定の状態が無い料理は、量と推定の印と kcal を出し、行の下に何も置かないこと")
        func notWaiting() throws {
            let row = try soupRow(of: card())

            #expect(row.quantity == "1杯")
            #expect(row.showsEstimateBadge)
            #expect(row.kilocalories == "40 kcal")
            #expect(row.note == nil)
        }

        @Test("推定できた料理は、待っていない料理と同じに見せること")
        func estimated() throws {
            let row = try soupRow(of: card(dishStatuses: [soupId: .estimated]))

            #expect(row.quantity == "1杯")
            #expect(row.kilocalories == "40 kcal")
            #expect(row.note == nil)
        }

        @Test("推定中の料理は、量と kcal を「—」にし、行の下に回る印と「推定しています…」を置くこと")
        func estimating() throws {
            let row = try soupRow(of: card(dishStatuses: [soupId: .estimating]))

            #expect(row.quantity == "—")
            #expect(!row.showsEstimateBadge)
            #expect(row.kilocalories == "—")
            #expect(row.note == .estimating)
            #expect(row.note?.text == "推定しています…")
            #expect(row.note?.showsSpinner == true)
        }

        @Test("量を直してある料理は、待っているあいだも直した量を出すこと")
        func waitingWithCorrectedQuantity() throws {
            let row = try soupRow(
                of: card(
                    soupQuantity: Dish.Quantity(value: 2, unit: "杯", source: .corrected),
                    dishStatuses: [soupId: .estimating]))

            #expect(row.quantity == "2杯")
            #expect(!row.showsEstimateBadge)
            #expect(row.kilocalories == "—")
        }

        @Test("翌日に推定の料理は、行の下に「今日はもう推定できないため、明日推定します」を置くこと")
        func deferred() throws {
            let row = try soupRow(of: card(dishStatuses: [soupId: .deferredToNextDay]))

            #expect(row.quantity == "—")
            #expect(row.kilocalories == "—")
            #expect(row.note?.text == "今日はもう推定できないため、明日推定します")
            #expect(row.note?.showsSpinner == false)
        }

        @Test("料理なし・推定できなかった料理は、前の量と 0 kcal を出し、行の下に「この名前からは材料を推定できませんでした」を置くこと")
        func unestimable() throws {
            for status in [DishEstimationStatus.noDishes, .failed] {
                let row = try soupRow(of: card(dishStatuses: [soupId: status]))

                #expect(row.quantity == "1杯")
                #expect(row.kilocalories == "0 kcal")
                #expect(row.note?.text == "この名前からは材料を推定できませんでした")
            }
        }

        @Test("料理を足す・名前を直す書き込みがまだ送れていない料理は、量と kcal を「—」にし、行の下に何も置かないこと")
        func unsent() throws {
            let row = try soupRow(
                of: card(dishStatuses: [soupId: .estimated], unsentDishIds: [soupId]))

            #expect(row.quantity == "—")
            #expect(row.kilocalories == "—")
            #expect(row.note == nil)
        }

        @Test("量の無い料理に推定の状態がまだ届いていなければ、まだ送れていないと同じに見せること")
        func addedDishWithoutStatus() throws {
            let row = try soupRow(of: card(soupQuantity: nil))

            #expect(row.quantity == "—")
            #expect(row.kilocalories == "—")
            #expect(row.note == nil)
        }

        @Test("写真を待っている食事の推定中の料理は、まだ送れていないと同じに見せること")
        func awaitingPhotos() throws {
            for recordedOnThisDevice in [true, false] {
                let row = try soupRow(
                    of: card(
                        status: .awaitingPhotos, recordedOnThisDevice: recordedOnThisDevice,
                        dishStatuses: [soupId: .estimating]))

                #expect(row.kilocalories == "—")
                #expect(row.note == nil)
            }
        }

        @Test("料理の画面で材料と栄養を出すのは、待っていない・推定できた料理だけにすること")
        func ingredientsShownOnlyWhenSettled() throws {
            let shown = try [
                nil, DishEstimationStatus.estimated, .estimating, .deferredToNextDay, .noDishes,
                .failed,
            ].map { status in
                try #require(
                    card(dishStatuses: status.map { [soupId: $0] } ?? [:]).contents.dishes.first {
                        $0.dish.id == soupId
                    }
                ).showsIngredientsAndNutrients
            }

            #expect(shown == [true, true, false, false, false, false])
        }
    }

    @Suite("「以上」")
    struct AtLeast {
        @Test("待っている料理があれば、食事の合計は分かる料理の分だけを足し、「以上」を付けること")
        func waitingDishMakesTotalsLowerBound() throws {
            let totals = try totals(of: card(dishStatuses: [soupId: .estimating]))

            #expect(totals[.energyKcal] == .atLeast(600))
            #expect(totals[.proteinG] == .atLeast(20))
            #expect(NutritionText.amount(totals[.energyKcal], of: .energyKcal) == "600 kcal 以上")
        }

        @Test("待っている料理が無ければ、「以上」を付けないこと")
        func noWaitingDish() throws {
            let totals = try totals(
                of: card(dishStatuses: [soupId: .estimated]))

            #expect(totals[.energyKcal] == .exactly(640))
        }

        @Test("通らなかった料理は 0 kcal として足し、「以上」を付けないこと")
        func unestimableDishIsKnown() throws {
            let totals = try totals(of: card(dishStatuses: [soupId: .failed]))

            #expect(totals[.energyKcal] == .exactly(600))
        }

        @Test("推定できた食事の料理がすべて待っているあいだは、合計を「—」にすること")
        func allDishesWaiting() throws {
            let totals = try totals(
                of: card(dishStatuses: [curryId: .estimating, soupId: .estimating]))

            #expect(NutritionText.amount(totals[.energyKcal], of: .energyKcal) == "—")
        }

        @Test("料理ごとに待つ食事は、日のまとめに分かる分を入れて「以上」を付け、推定が済んでいない食事に数えないこと")
        func dayFoodWithWaitingDish() throws {
            let figures = try #require(
                DayFood(meals: [card(dishStatuses: [soupId: .estimating])]).figures)

            #expect(figures.totals[.energyKcal] == .atLeast(600))
            #expect(figures.pendingMealCount == 0)
        }

        @Test("日の食事が料理ごとに待つものだけで、分かる値が無いあいだは、推定しているところとして見せること")
        func dayFoodAllWaiting() throws {
            let food = DayFood(meals: [
                try card(dishStatuses: [curryId: .estimating, soupId: .estimating])
            ])

            #expect(food == .allPending)
        }
    }

    @Suite("写真の推定が済んでいない食事に料理を足したとき")
    struct AddedToUnsettledMeal {
        @Test("推定できた足した料理の分だけで、待っている料理が無くても合計に「以上」を付けること")
        func totalsAreLowerBound() throws {
            for status in [
                MealEstimationStatus.estimating, .deferredToNextDay, .awaitingPhotos, nil,
            ] {
                let totals = try totals(
                    of: card(
                        status: status, dishStatuses: [soupId: .estimated], withCurry: false))

                #expect(totals[.energyKcal] == .atLeast(40))
            }
        }

        @Test("分かる料理が1つも無いあいだは、合計を出さないこと")
        func noKnownDish() throws {
            let card = try card(
                status: .estimating, dishStatuses: [soupId: .estimating], withCurry: false)

            #expect(card.nutrition == .pending)
        }

        @Test("日のまとめに足した料理の分を入れて「以上」を付け、推定が済んでいない食事に数えること")
        func dayFood() throws {
            let figures = try #require(
                DayFood(meals: [
                    card(status: .estimating, dishStatuses: [soupId: .estimated], withCurry: false)
                ]).figures)

            #expect(figures.totals[.energyKcal] == .atLeast(40))
            #expect(figures.pendingMealCount == 1)
        }
    }

    @Suite("料理を足したあとの食事")
    struct AfterAdding {
        func addedCard(_ status: MealEstimationStatus?, recordedOnThisDevice: Bool = true)
            throws -> MealCard
        {
            try card(
                status: status, recordedOnThisDevice: recordedOnThisDevice,
                dishStatuses: [soupId: .estimating], withCurry: false)
        }

        @Test("カードの名前の場所には、どの状態でも料理の名前を置くこと")
        func cardNames() throws {
            for status in [
                MealEstimationStatus.awaitingPhotos, .estimating, .deferredToNextDay, .noDishes,
                .failed, .estimated, nil,
            ] {
                #expect(try addedCard(status).namePlace.dishNames == "味噌汁")
            }
        }

        @Test("カードの状態の1行は、推定中と翌日に推定だけ、写真の推定が済むまで残すこと")
        func cardStatusLine() throws {
            #expect(try addedCard(.estimating).namePlace.statusLine == "推定しています…")
            #expect(
                try addedCard(.deferredToNextDay).namePlace.statusLine
                    == "今日はもう推定できないため、明日推定します")
            for status in [
                MealEstimationStatus.awaitingPhotos, .noDishes, .failed, .estimated, nil,
            ] {
                #expect(try addedCard(status).namePlace.statusLine == nil)
            }
        }

        @Test("食事の画面の料理の一覧の上の食事の状態は、推定中と翌日に推定だけ残すこと")
        func mealScreenNote() throws {
            #expect(try addedCard(.estimating).dishListNote == .estimating)
            #expect(try addedCard(.deferredToNextDay).dishListNote == .deferredToNextDay)
            for status in [
                MealEstimationStatus.awaitingPhotos, .noDishes, .failed, .estimated, nil,
            ] {
                #expect(try addedCard(status).dishListNote == nil)
            }
        }

        @Test("料理が1つも無いあいだは、#188 のまま状態ごとの1行を置くこと")
        func withoutDishes() throws {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            let notes = [MealEstimationStatus.estimating, .deferredToNextDay, .noDishes, .failed]
                .map {
                    MealCard(meal: meal, status: $0, recordedOnThisDevice: true).dishListNote
                }
            let names = [MealEstimationStatus.estimating, .noDishes, .estimated].map {
                MealCard(meal: meal, status: $0, recordedOnThisDevice: true).namePlace
            }

            #expect(notes == [.estimating, .deferredToNextDay, .noDishes, .failed])
            #expect(
                names.map(\.statusLine) == ["推定しています…", "写真に料理が見つかりませんでした", nil])
            #expect(names.allSatisfy { $0.dishNames == nil })
        }

        @Test("料理なし・推定できなかった食事に料理が無いあいだは、料理を足す添え書きを置くこと")
        func addDishHint() throws {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")

            #expect(
                MealCard(meal: meal, status: .noDishes, recordedOnThisDevice: true).dishListNote?
                    .addDishHint == "料理の名前を入れると、量と材料を推定します。")
            #expect(
                MealCard(meal: meal, status: .estimating, recordedOnThisDevice: true).dishListNote?
                    .addDishHint == nil)
        }
    }
}
