import Foundation
import NuToriCore
import Testing

@Suite("食事の画面と料理の画面に出す操作")
struct MealEditOfferTests {
    /// 料理の待ちごとに1品ずつ持つ食事（まだ送れていない・推定中・翌日に推定・待っていない）
    struct Fixture {
        let offer: MealEditOffer
        let notSent: DishContents
        let estimating: DishContents
        let deferredToNextDay: DishContents
        let notWaiting: DishContents

        var dishes: [DishContents] { [notSent, estimating, deferredToNextDay, notWaiting] }

        init(status: MealEstimationStatus?, recordedOnThisDevice: Bool) throws {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            let notSentId = UUID()
            let estimatingId = UUID()
            let deferredId = UUID()
            let notWaitingId = UUID()
            let dishes = [notSentId, estimatingId, deferredId, notWaitingId].enumerated().map {
                position, id in
                Dish.fixture(id: id, mealId: meal.id, positionInMeal: position)
            }
            let card = MealCard(
                meal: meal, status: status, recordedOnThisDevice: recordedOnThisDevice,
                dishes: dishes,
                ingredients: dishes.map { .fixture(dishId: $0.id, nutrients: [.energyKcal: 100]) },
                dishEstimationStatuses: [
                    notSentId: .estimated, estimatingId: .estimating,
                    deferredId: .deferredToNextDay, notWaitingId: .estimated,
                ],
                unsentDishIds: [notSentId])
            func contents(_ id: UUID) throws -> DishContents {
                try #require(card.contents.dishes.first { $0.dish.id == id })
            }
            offer = MealEditOffer(card: card)
            notSent = try contents(notSentId)
            estimating = try contents(estimatingId)
            deferredToNextDay = try contents(deferredId)
            notWaiting = try contents(notWaitingId)
        }
    }

    @Suite("まだ送れていない食事のとき")
    struct NotSent {
        let fixture: Fixture

        init() throws {
            fixture = try Fixture(status: nil, recordedOnThisDevice: true)
        }

        @Test("「料理を足す」を押せなくし、推定が終わると足せることを添えること")
        func waitsToAddDish() {
            #expect(fixture.offer.dishAddition == .disabled(note: "推定が終わると足せます。"))
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(!fixture.offer.deletesDishBySwipe)
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).editsNameAndQuantity })
            #expect(
                fixture.dishes.allSatisfy {
                    fixture.offer.dishScreen($0).waitNote == "推定が終わると直せます。"
                })
            #expect(fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).deletesDish })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.dishes.allSatisfy {
                    !fixture.offer.dishScreen($0).showsIngredientsAndNutrients
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.offer.dishScreen(fixture.notSent).progressNote == nil)
            #expect(fixture.offer.dishScreen(fixture.estimating).progressNote == .estimating)
            #expect(
                fixture.offer.dishScreen(fixture.deferredToNextDay).progressNote
                    == .deferredToNextDay)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).progressNote == nil)
        }
    }

    @Suite("ほかの端末で記録した、写真を待っている食事のとき")
    struct AwaitingPhotos {
        let fixture: Fixture

        init() throws {
            fixture = try Fixture(status: .awaitingPhotos, recordedOnThisDevice: false)
        }

        @Test("「料理を足す」を押せなくし、推定が終わると足せることを添えること")
        func waitsToAddDish() {
            #expect(fixture.offer.dishAddition == .disabled(note: "推定が終わると足せます。"))
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(!fixture.offer.deletesDishBySwipe)
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).editsNameAndQuantity })
            #expect(
                fixture.dishes.allSatisfy {
                    fixture.offer.dishScreen($0).waitNote == "推定が終わると直せます。"
                })
            #expect(fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).deletesDish })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.dishes.allSatisfy {
                    !fixture.offer.dishScreen($0).showsIngredientsAndNutrients
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.offer.dishScreen(fixture.notSent).progressNote == nil)
            #expect(fixture.offer.dishScreen(fixture.estimating).progressNote == .estimating)
            #expect(
                fixture.offer.dishScreen(fixture.deferredToNextDay).progressNote
                    == .deferredToNextDay)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).progressNote == nil)
        }
    }

    @Suite("推定中の食事のとき")
    struct Estimating {
        let fixture: Fixture

        init() throws {
            fixture = try Fixture(status: .estimating, recordedOnThisDevice: true)
        }

        @Test("「料理を足す」を押せなくし、推定が終わると足せることを添えること")
        func waitsToAddDish() {
            #expect(fixture.offer.dishAddition == .disabled(note: "推定が終わると足せます。"))
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(!fixture.offer.deletesDishBySwipe)
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).editsNameAndQuantity })
            #expect(
                fixture.dishes.allSatisfy {
                    fixture.offer.dishScreen($0).waitNote == "推定が終わると直せます。"
                })
            #expect(fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).deletesDish })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.dishes.allSatisfy {
                    !fixture.offer.dishScreen($0).showsIngredientsAndNutrients
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.offer.dishScreen(fixture.notSent).progressNote == nil)
            #expect(fixture.offer.dishScreen(fixture.estimating).progressNote == .estimating)
            #expect(
                fixture.offer.dishScreen(fixture.deferredToNextDay).progressNote
                    == .deferredToNextDay)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).progressNote == nil)
        }
    }

    @Suite("翌日に推定の食事のとき")
    struct DeferredToNextDay {
        let fixture: Fixture

        init() throws {
            fixture = try Fixture(status: .deferredToNextDay, recordedOnThisDevice: true)
        }

        @Test("「料理を足す」を押せなくし、推定が終わると足せることを添えること")
        func waitsToAddDish() {
            #expect(fixture.offer.dishAddition == .disabled(note: "推定が終わると足せます。"))
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(!fixture.offer.deletesDishBySwipe)
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).editsNameAndQuantity })
            #expect(
                fixture.dishes.allSatisfy {
                    fixture.offer.dishScreen($0).waitNote == "推定が終わると直せます。"
                })
            #expect(fixture.dishes.allSatisfy { !fixture.offer.dishScreen($0).deletesDish })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.dishes.allSatisfy {
                    !fixture.offer.dishScreen($0).showsIngredientsAndNutrients
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.offer.dishScreen(fixture.notSent).progressNote == nil)
            #expect(fixture.offer.dishScreen(fixture.estimating).progressNote == .estimating)
            #expect(
                fixture.offer.dishScreen(fixture.deferredToNextDay).progressNote
                    == .deferredToNextDay)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).progressNote == nil)
        }
    }

    @Suite("推定できた食事のとき")
    struct Estimated {
        let fixture: Fixture

        init() throws {
            fixture = try Fixture(status: .estimated, recordedOnThisDevice: true)
        }

        @Test("「料理を足す」を押せること")
        func addsDish() {
            #expect(fixture.offer.dishAddition == .offered)
        }

        @Test("どの料理の行も、左へ送って消せること")
        func deletesEveryDishBySwipe() {
            #expect(fixture.offer.deletesDishBySwipe)
        }

        @Test("待っていない料理の画面では、名前と量を直せて、推定が終わると直せることを添えないこと")
        func editsNotWaitingDish() {
            #expect(fixture.offer.dishScreen(fixture.notWaiting).editsNameAndQuantity)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).waitNote == nil)
        }

        @Test("推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）の画面では、名前と量の欄を押せなくして推定が終わると直せることを添えること")
        func editsNoWaitingDish() {
            let waiting = [fixture.notSent, fixture.estimating, fixture.deferredToNextDay]
            #expect(waiting.allSatisfy { !fixture.offer.dishScreen($0).editsNameAndQuantity })
            #expect(
                waiting.allSatisfy {
                    fixture.offer.dishScreen($0).waitNote == "推定が終わると直せます。"
                })
        }

        @Test("どの料理の画面でも、「この料理を削除」を出すこと")
        func deletesEveryDish() {
            #expect(fixture.dishes.allSatisfy { fixture.offer.dishScreen($0).deletesDish })
        }

        @Test("待っていない料理の画面にだけ、材料と栄養を出すこと")
        func showsIngredientsOnlyForNotWaiting() {
            #expect(!fixture.offer.dishScreen(fixture.notSent).showsIngredientsAndNutrients)
            #expect(!fixture.offer.dishScreen(fixture.estimating).showsIngredientsAndNutrients)
            #expect(
                !fixture.offer.dishScreen(fixture.deferredToNextDay).showsIngredientsAndNutrients)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).showsIngredientsAndNutrients)
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.offer.dishScreen(fixture.notSent).progressNote == nil)
            #expect(fixture.offer.dishScreen(fixture.estimating).progressNote == .estimating)
            #expect(
                fixture.offer.dishScreen(fixture.deferredToNextDay).progressNote
                    == .deferredToNextDay)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).progressNote == nil)
        }
    }

    @Suite("推定できた食事の、量の無い料理（足したばかり）の画面")
    struct DishWithoutQuantity {
        /// 推定できた食事と、量の無い料理1品。`dishStatus` が nil なら、料理を足す書き込みがまだ送れていない
        static func offer(dishStatus: DishEstimationStatus?) throws -> MealEditOffer.DishScreenOffer
        {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            let dish = Dish.fixture(mealId: meal.id, quantity: nil)
            let card = MealCard(
                meal: meal, status: .estimated, recordedOnThisDevice: true, dishes: [dish],
                ingredients: [], dishEstimationStatuses: dishStatus.map { [dish.id: $0] } ?? [:],
                unsentDishIds: dishStatus == nil ? [dish.id] : [])
            let contents = try #require(card.contents.dishes.first)
            return MealEditOffer(card: card).dishScreen(contents)
        }

        @Suite("推定し直しを待っているとき")
        struct Waiting {
            let offer: MealEditOffer.DishScreenOffer

            init() throws {
                offer = try DishWithoutQuantity.offer(dishStatus: nil)
            }

            @Test("名前の欄を押せなくし、量の行に「—」を置くこと")
            func showsEmptyQuantity() {
                #expect(offer.nameAndQuantity == .disabled(quantity: nil))
            }
        }

        @Suite("推定し直しが通らず、直せるとき")
        struct Unestimable {
            let offer: MealEditOffer.DishScreenOffer

            init() throws {
                offer = try DishWithoutQuantity.offer(dishStatus: .noDishes)
            }

            @Test("名前を直せる欄にし、量の行を置かないこと")
            func showsNoQuantity() {
                #expect(offer.nameAndQuantity == .editable(quantity: nil))
            }
        }
    }

    @Suite("料理なしの食事のとき")
    struct NoDishes {
        let fixture: Fixture

        init() throws {
            fixture = try Fixture(status: .noDishes, recordedOnThisDevice: true)
        }

        @Test("「料理を足す」を押せること")
        func addsDish() {
            #expect(fixture.offer.dishAddition == .offered)
        }

        @Test("どの料理の行も、左へ送って消せること")
        func deletesEveryDishBySwipe() {
            #expect(fixture.offer.deletesDishBySwipe)
        }

        @Test("待っていない料理の画面では、名前と量を直せて、推定が終わると直せることを添えないこと")
        func editsNotWaitingDish() {
            #expect(fixture.offer.dishScreen(fixture.notWaiting).editsNameAndQuantity)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).waitNote == nil)
        }

        @Test("推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）の画面では、名前と量の欄を押せなくして推定が終わると直せることを添えること")
        func editsNoWaitingDish() {
            let waiting = [fixture.notSent, fixture.estimating, fixture.deferredToNextDay]
            #expect(waiting.allSatisfy { !fixture.offer.dishScreen($0).editsNameAndQuantity })
            #expect(
                waiting.allSatisfy {
                    fixture.offer.dishScreen($0).waitNote == "推定が終わると直せます。"
                })
        }

        @Test("どの料理の画面でも、「この料理を削除」を出すこと")
        func deletesEveryDish() {
            #expect(fixture.dishes.allSatisfy { fixture.offer.dishScreen($0).deletesDish })
        }

        @Test("待っていない料理の画面にだけ、材料と栄養を出すこと")
        func showsIngredientsOnlyForNotWaiting() {
            #expect(!fixture.offer.dishScreen(fixture.notSent).showsIngredientsAndNutrients)
            #expect(!fixture.offer.dishScreen(fixture.estimating).showsIngredientsAndNutrients)
            #expect(
                !fixture.offer.dishScreen(fixture.deferredToNextDay).showsIngredientsAndNutrients)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).showsIngredientsAndNutrients)
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.offer.dishScreen(fixture.notSent).progressNote == nil)
            #expect(fixture.offer.dishScreen(fixture.estimating).progressNote == .estimating)
            #expect(
                fixture.offer.dishScreen(fixture.deferredToNextDay).progressNote
                    == .deferredToNextDay)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).progressNote == nil)
        }
    }

    @Suite("推定できなかった食事のとき")
    struct Failed {
        let fixture: Fixture

        init() throws {
            fixture = try Fixture(status: .failed, recordedOnThisDevice: true)
        }

        @Test("「料理を足す」を押せること")
        func addsDish() {
            #expect(fixture.offer.dishAddition == .offered)
        }

        @Test("どの料理の行も、左へ送って消せること")
        func deletesEveryDishBySwipe() {
            #expect(fixture.offer.deletesDishBySwipe)
        }

        @Test("待っていない料理の画面では、名前と量を直せて、推定が終わると直せることを添えないこと")
        func editsNotWaitingDish() {
            #expect(fixture.offer.dishScreen(fixture.notWaiting).editsNameAndQuantity)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).waitNote == nil)
        }

        @Test("推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）の画面では、名前と量の欄を押せなくして推定が終わると直せることを添えること")
        func editsNoWaitingDish() {
            let waiting = [fixture.notSent, fixture.estimating, fixture.deferredToNextDay]
            #expect(waiting.allSatisfy { !fixture.offer.dishScreen($0).editsNameAndQuantity })
            #expect(
                waiting.allSatisfy {
                    fixture.offer.dishScreen($0).waitNote == "推定が終わると直せます。"
                })
        }

        @Test("どの料理の画面でも、「この料理を削除」を出すこと")
        func deletesEveryDish() {
            #expect(fixture.dishes.allSatisfy { fixture.offer.dishScreen($0).deletesDish })
        }

        @Test("待っていない料理の画面にだけ、材料と栄養を出すこと")
        func showsIngredientsOnlyForNotWaiting() {
            #expect(!fixture.offer.dishScreen(fixture.notSent).showsIngredientsAndNutrients)
            #expect(!fixture.offer.dishScreen(fixture.estimating).showsIngredientsAndNutrients)
            #expect(
                !fixture.offer.dishScreen(fixture.deferredToNextDay).showsIngredientsAndNutrients)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).showsIngredientsAndNutrients)
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.offer.dishScreen(fixture.notSent).progressNote == nil)
            #expect(fixture.offer.dishScreen(fixture.estimating).progressNote == .estimating)
            #expect(
                fixture.offer.dishScreen(fixture.deferredToNextDay).progressNote
                    == .deferredToNextDay)
            #expect(fixture.offer.dishScreen(fixture.notWaiting).progressNote == nil)
        }
    }
}
