import Foundation
import NuToriCore
import Testing

@Suite("食事の画面と料理の画面に出す操作")
struct MealEditOfferTests {
    /// 料理の待ちごとに1品ずつ持つ食事（まだ送れていない・推定中・翌日に推定・待っていない）
    struct Fixture {
        let offer: MealEditOffer
        let notSent: MealEditOffer.DishScreenOffer
        let estimating: MealEditOffer.DishScreenOffer
        let deferredToNextDay: MealEditOffer.DishScreenOffer
        let notWaiting: MealEditOffer.DishScreenOffer

        var screens: [MealEditOffer.DishScreenOffer] {
            [notSent, estimating, deferredToNextDay, notWaiting]
        }
        var dishIds: [UUID] { screens.map(\.contents.dish.id) }

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
            let offer = MealEditOffer(card: card)
            func screen(_ id: UUID) throws -> MealEditOffer.DishScreenOffer {
                try #require(offer.dishScreen(dishId: id, rejectedLines: []))
            }
            self.offer = offer
            notSent = try screen(notSentId)
            estimating = try screen(estimatingId)
            deferredToNextDay = try screen(deferredId)
            notWaiting = try screen(notWaitingId)
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
            #expect(fixture.offer.addDishWaitNote == "推定が終わると足せます。")
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(fixture.dishIds.allSatisfy { fixture.offer.rowDeletion(of: $0) == .hidden })
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.screens.allSatisfy { !$0.editsNameAndQuantity })
            #expect(
                fixture.screens.allSatisfy {
                    $0.footerNote(editingName: false) == "推定が終わると直せます。"
                })
            #expect(fixture.screens.allSatisfy { $0.deletion == .hidden })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.screens.allSatisfy {
                    $0.ingredients == nil
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.notSent.progressNote == nil)
            #expect(fixture.estimating.progressNote == .estimating)
            #expect(
                fixture.deferredToNextDay.progressNote
                    == .deferredToNextDay)
            #expect(fixture.notWaiting.progressNote == nil)
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
            #expect(fixture.offer.addDishWaitNote == "推定が終わると足せます。")
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(fixture.dishIds.allSatisfy { fixture.offer.rowDeletion(of: $0) == .hidden })
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.screens.allSatisfy { !$0.editsNameAndQuantity })
            #expect(
                fixture.screens.allSatisfy {
                    $0.footerNote(editingName: false) == "推定が終わると直せます。"
                })
            #expect(fixture.screens.allSatisfy { $0.deletion == .hidden })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.screens.allSatisfy {
                    $0.ingredients == nil
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.notSent.progressNote == nil)
            #expect(fixture.estimating.progressNote == .estimating)
            #expect(
                fixture.deferredToNextDay.progressNote
                    == .deferredToNextDay)
            #expect(fixture.notWaiting.progressNote == nil)
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
            #expect(fixture.offer.addDishWaitNote == "推定が終わると足せます。")
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(fixture.dishIds.allSatisfy { fixture.offer.rowDeletion(of: $0) == .hidden })
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.screens.allSatisfy { !$0.editsNameAndQuantity })
            #expect(
                fixture.screens.allSatisfy {
                    $0.footerNote(editingName: false) == "推定が終わると直せます。"
                })
            #expect(fixture.screens.allSatisfy { $0.deletion == .hidden })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.screens.allSatisfy {
                    $0.ingredients == nil
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.notSent.progressNote == nil)
            #expect(fixture.estimating.progressNote == .estimating)
            #expect(
                fixture.deferredToNextDay.progressNote
                    == .deferredToNextDay)
            #expect(fixture.notWaiting.progressNote == nil)
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
            #expect(fixture.offer.addDishWaitNote == "推定が終わると足せます。")
        }

        @Test("どの料理の行も、左へ送って消せないこと")
        func deletesNoDishBySwipe() {
            #expect(fixture.dishIds.allSatisfy { fixture.offer.rowDeletion(of: $0) == .hidden })
        }

        @Test("どの料理の画面でも、名前と量の欄を押せなくして推定が終わると直せることを添え、「この料理を削除」を出さないこと")
        func editsNoDish() {
            #expect(
                fixture.screens.allSatisfy { !$0.editsNameAndQuantity })
            #expect(
                fixture.screens.allSatisfy {
                    $0.footerNote(editingName: false) == "推定が終わると直せます。"
                })
            #expect(fixture.screens.allSatisfy { $0.deletion == .hidden })
        }

        @Test("待っていない料理の画面にも、材料と栄養を出さないこと")
        func showsNoIngredients() {
            #expect(
                fixture.screens.allSatisfy {
                    $0.ingredients == nil
                })
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.notSent.progressNote == nil)
            #expect(fixture.estimating.progressNote == .estimating)
            #expect(
                fixture.deferredToNextDay.progressNote
                    == .deferredToNextDay)
            #expect(fixture.notWaiting.progressNote == nil)
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
            #expect(fixture.offer.addDishWaitNote == nil)
        }

        @Test("どの料理の行も、左へ送って消せること")
        func deletesEveryDishBySwipe() {
            #expect(fixture.dishIds.allSatisfy { fixture.offer.rowDeletion(of: $0) == .dish })
        }

        @Test("待っていない料理の画面では、名前と量を直せて、量を変えたときの注記を添えること")
        func editsNotWaitingDish() {
            #expect(fixture.notWaiting.editsNameAndQuantity)
            #expect(
                fixture.notWaiting.footerNote(editingName: false)
                    == "量を変えると、材料の量も同じ割合で変わります。")
        }

        @Test("推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）の画面では、名前と量の欄を押せなくして推定が終わると直せることを添えること")
        func editsNoWaitingDish() {
            let waiting = [fixture.notSent, fixture.estimating, fixture.deferredToNextDay]
            #expect(waiting.allSatisfy { !$0.editsNameAndQuantity })
            #expect(
                waiting.allSatisfy {
                    $0.footerNote(editingName: false) == "推定が終わると直せます。"
                })
        }

        @Test("どの料理の画面でも、「この料理を削除」を出すこと")
        func deletesEveryDish() {
            #expect(fixture.screens.allSatisfy { $0.deletion == .dish })
        }

        @Test("待っていない料理の画面にだけ、材料と栄養を出すこと")
        func showsIngredientsOnlyForNotWaiting() {
            #expect(fixture.notSent.ingredients == nil)
            #expect(fixture.estimating.ingredients == nil)
            #expect(
                fixture.deferredToNextDay.ingredients == nil)
            #expect(fixture.notWaiting.ingredients != nil)
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.notSent.progressNote == nil)
            #expect(fixture.estimating.progressNote == .estimating)
            #expect(
                fixture.deferredToNextDay.progressNote
                    == .deferredToNextDay)
            #expect(fixture.notWaiting.progressNote == nil)
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
            return try #require(
                MealEditOffer(card: card).dishScreen(dishId: dish.id, rejectedLines: []))
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
            #expect(fixture.offer.addDishWaitNote == nil)
        }

        @Test("どの料理の行も、左へ送って消せること")
        func deletesEveryDishBySwipe() {
            #expect(fixture.dishIds.allSatisfy { fixture.offer.rowDeletion(of: $0) == .dish })
        }

        @Test("待っていない料理の画面では、名前と量を直せて、量を変えたときの注記を添えること")
        func editsNotWaitingDish() {
            #expect(fixture.notWaiting.editsNameAndQuantity)
            #expect(
                fixture.notWaiting.footerNote(editingName: false)
                    == "量を変えると、材料の量も同じ割合で変わります。")
        }

        @Test("推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）の画面では、名前と量の欄を押せなくして推定が終わると直せることを添えること")
        func editsNoWaitingDish() {
            let waiting = [fixture.notSent, fixture.estimating, fixture.deferredToNextDay]
            #expect(waiting.allSatisfy { !$0.editsNameAndQuantity })
            #expect(
                waiting.allSatisfy {
                    $0.footerNote(editingName: false) == "推定が終わると直せます。"
                })
        }

        @Test("どの料理の画面でも、「この料理を削除」を出すこと")
        func deletesEveryDish() {
            #expect(fixture.screens.allSatisfy { $0.deletion == .dish })
        }

        @Test("待っていない料理の画面にだけ、材料と栄養を出すこと")
        func showsIngredientsOnlyForNotWaiting() {
            #expect(fixture.notSent.ingredients == nil)
            #expect(fixture.estimating.ingredients == nil)
            #expect(
                fixture.deferredToNextDay.ingredients == nil)
            #expect(fixture.notWaiting.ingredients != nil)
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.notSent.progressNote == nil)
            #expect(fixture.estimating.progressNote == .estimating)
            #expect(
                fixture.deferredToNextDay.progressNote
                    == .deferredToNextDay)
            #expect(fixture.notWaiting.progressNote == nil)
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
            #expect(fixture.offer.addDishWaitNote == nil)
        }

        @Test("どの料理の行も、左へ送って消せること")
        func deletesEveryDishBySwipe() {
            #expect(fixture.dishIds.allSatisfy { fixture.offer.rowDeletion(of: $0) == .dish })
        }

        @Test("待っていない料理の画面では、名前と量を直せて、量を変えたときの注記を添えること")
        func editsNotWaitingDish() {
            #expect(fixture.notWaiting.editsNameAndQuantity)
            #expect(
                fixture.notWaiting.footerNote(editingName: false)
                    == "量を変えると、材料の量も同じ割合で変わります。")
        }

        @Test("推定し直しを待っている料理（まだ送れていない・推定中・翌日に推定）の画面では、名前と量の欄を押せなくして推定が終わると直せることを添えること")
        func editsNoWaitingDish() {
            let waiting = [fixture.notSent, fixture.estimating, fixture.deferredToNextDay]
            #expect(waiting.allSatisfy { !$0.editsNameAndQuantity })
            #expect(
                waiting.allSatisfy {
                    $0.footerNote(editingName: false) == "推定が終わると直せます。"
                })
        }

        @Test("どの料理の画面でも、「この料理を削除」を出すこと")
        func deletesEveryDish() {
            #expect(fixture.screens.allSatisfy { $0.deletion == .dish })
        }

        @Test("待っていない料理の画面にだけ、材料と栄養を出すこと")
        func showsIngredientsOnlyForNotWaiting() {
            #expect(fixture.notSent.ingredients == nil)
            #expect(fixture.estimating.ingredients == nil)
            #expect(
                fixture.deferredToNextDay.ingredients == nil)
            #expect(fixture.notWaiting.ingredients != nil)
        }

        @Test("推定中と翌日に推定の料理の画面に、待ちの1行を出すこと")
        func showsProgressNotes() {
            #expect(fixture.notSent.progressNote == nil)
            #expect(fixture.estimating.progressNote == .estimating)
            #expect(
                fixture.deferredToNextDay.progressNote
                    == .deferredToNextDay)
            #expect(fixture.notWaiting.progressNote == nil)
        }
    }

    /// 料理だけを持つ食事（材料は無い）。`unsentDishIds` は、料理を足す・名前を直す書き込みがまだ送れていない料理
    static func offer(
        status: MealEstimationStatus, dishes: (_ mealId: UUID) -> [Dish],
        dishEstimationStatuses: (_ dishes: [Dish]) -> [UUID: DishEstimationStatus] = { _ in [:] },
        unsentDishIds: (_ dishes: [Dish]) -> Set<UUID> = { _ in [] }
    ) throws -> MealEditOffer {
        let meal = try Meal.fixture(
            eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
        let dishes = dishes(meal.id)
        return MealEditOffer(
            card: MealCard(
                meal: meal, status: status, recordedOnThisDevice: true, dishes: dishes,
                ingredients: [], dishEstimationStatuses: dishEstimationStatuses(dishes),
                unsentDishIds: unsentDishIds(dishes)))
    }

    /// 推定できた食事の、料理1品の画面
    static func screen(
        quantity: Dish.Quantity?, dishStatus: DishEstimationStatus? = nil
    ) throws -> MealEditOffer.DishScreenOffer {
        let dishId = UUID()
        let offer = try offer(
            status: .estimated,
            dishes: { [.fixture(id: dishId, mealId: $0, quantity: quantity)] },
            dishEstimationStatuses: { _ in dishStatus.map { [dishId: $0] } ?? [:] })
        return try #require(offer.dishScreen(dishId: dishId, rejectedLines: []))
    }

    static let estimatedQuantity = Dish.Quantity(value: 1.5, unit: "杯", source: .estimated)
    static let correctedQuantity = Dish.Quantity(value: 1.5, unit: "杯", source: .corrected)

    @Suite("料理の画面の量の欄")
    struct QuantityField {
        @Suite("推定したままの量のとき")
        struct Estimated {
            let field: MealEditOffer.DishScreenOffer.QuantityField?

            init() throws {
                field = try MealEditOfferTests.screen(
                    quantity: MealEditOfferTests.estimatedQuantity
                ).quantityField
            }

            @Test("数だけを欄に入れ、単位を添えて推定の印を付けること")
            func showsNumberWithBadge() throws {
                let field = try #require(field)

                #expect(field.text == "1.5")
                #expect(field.unit == "杯")
                #expect(field.showsEstimateBadge)
            }
        }

        @Suite("直した量のとき")
        struct Corrected {
            let field: MealEditOffer.DishScreenOffer.QuantityField?

            init() throws {
                field = try MealEditOfferTests.screen(
                    quantity: MealEditOfferTests.correctedQuantity
                ).quantityField
            }

            @Test("推定の印を付けないこと")
            func showsNoBadge() throws {
                let field = try #require(field)

                #expect(field.text == "1.5")
                #expect(!field.showsEstimateBadge)
            }
        }

        @Suite("推定し直しを待っている料理の、推定したままの量のとき")
        struct WaitingWithEstimated {
            let field: MealEditOffer.DishScreenOffer.QuantityField?

            init() throws {
                field = try MealEditOfferTests.screen(
                    quantity: MealEditOfferTests.estimatedQuantity, dishStatus: .estimating
                ).quantityField
            }

            @Test("食事の画面の料理の行と同じく欄を空けて「—」にすること")
            func showsDash() throws {
                let field = try #require(field)

                #expect(field.text == "")
                #expect(field.placeholder == "—")
                #expect(!field.showsEstimateBadge)
            }
        }

        @Suite("推定し直しを待っている料理の、直してある量のとき")
        struct WaitingWithCorrected {
            let field: MealEditOffer.DishScreenOffer.QuantityField?

            init() throws {
                field = try MealEditOfferTests.screen(
                    quantity: MealEditOfferTests.correctedQuantity, dishStatus: .deferredToNextDay
                ).quantityField
            }

            @Test("欄に入れること")
            func showsCorrectedQuantity() throws {
                let field = try #require(field)

                #expect(field.text == "1.5")
            }
        }
    }

    @Suite("料理の画面の、名前と量の下の注記")
    struct FooterNote {
        @Suite("直せる、推定したままの量の料理のとき")
        struct Estimated {
            let screen: MealEditOffer.DishScreenOffer

            init() throws {
                screen = try MealEditOfferTests.screen(
                    quantity: MealEditOfferTests.estimatedQuantity)
            }

            @Test("名前の欄を選んでいなければ、量を変えると材料も同じ割合で変わることを書くこと")
            func describesProportionalChange() {
                #expect(screen.footerNote(editingName: false) == "量を変えると、材料の量も同じ割合で変わります。")
            }

            @Test("名前の欄を選んでいれば、量と材料を推定し直すことを書くこと")
            func describesReestimation() {
                #expect(screen.footerNote(editingName: true) == "名前を変えると、量と材料を推定し直します。")
            }
        }

        @Suite("直せる、直した量の料理のとき")
        struct Corrected {
            let screen: MealEditOffer.DishScreenOffer

            init() throws {
                screen = try MealEditOfferTests.screen(
                    quantity: MealEditOfferTests.correctedQuantity)
            }

            @Test("名前の欄を選んでいれば、量はそのままで材料を推定し直すことを書くこと")
            func describesIngredientReestimation() {
                #expect(
                    screen.footerNote(editingName: true) == "名前を変えると、材料を推定し直します。量はそのままです。")
            }
        }

        @Suite("直せる、量の無い料理（推定し直しが通らなかった）のとき")
        struct WithoutQuantity {
            let screen: MealEditOffer.DishScreenOffer

            init() throws {
                screen = try MealEditOfferTests.screen(quantity: nil, dishStatus: .noDishes)
            }

            @Test("名前の欄を選んでいなければ、注記を出さないこと")
            func showsNoNote() {
                #expect(screen.footerNote(editingName: false) == nil)
            }

            @Test("名前の欄を選んでいれば、量と材料を推定し直すことを書くこと")
            func describesReestimation() {
                #expect(screen.footerNote(editingName: true) == "名前を変えると、量と材料を推定し直します。")
            }
        }

        @Suite("推定し直しを待っていて直せない料理のとき")
        struct Waiting {
            let screen: MealEditOffer.DishScreenOffer

            init() throws {
                screen = try MealEditOfferTests.screen(
                    quantity: MealEditOfferTests.estimatedQuantity, dishStatus: .estimating)
            }

            @Test("名前の欄を選んでいても、直したときの注記の代わりに推定が終わると直せることを書くこと")
            func describesWaitOverEditingNote() {
                #expect(screen.footerNote(editingName: true) == "推定が終わると直せます。")
            }
        }
    }

    @Suite("料理を消すときの、最後の1品の数え方")
    struct LastDish {
        @Suite("推定できた食事に、料理が1品だけあるとき")
        struct OnlyDish {
            let offer: MealEditOffer
            let dishId: UUID

            init() throws {
                let dishId = UUID()
                offer = try MealEditOfferTests.offer(
                    status: .estimated, dishes: { [.fixture(id: dishId, mealId: $0)] })
                self.dishId = dishId
            }

            @Test("料理の行を左へ送ると、確かめてから食事ごと消すこと")
            func confirmsMealDeletionBySwipe() {
                #expect(offer.rowDeletion(of: dishId) == .mealAfterConfirmation)
            }

            @Test("料理の画面の「この料理を削除」も、確かめてから食事ごと消すこと")
            func confirmsMealDeletionOnDishScreen() {
                #expect(
                    offer.dishScreen(dishId: dishId, rejectedLines: [])?.deletion
                        == .mealAfterConfirmation)
            }
        }

        @Suite("推定できた食事に、推定できた料理と、足したばかりでまだ送れていない料理があるとき")
        struct WithAddedDish {
            let offer: MealEditOffer
            let estimatedDishId: UUID
            let addedDishId: UUID

            init() throws {
                let estimatedDishId = UUID()
                let addedDishId = UUID()
                offer = try MealEditOfferTests.offer(
                    status: .estimated,
                    dishes: {
                        [
                            .fixture(id: estimatedDishId, mealId: $0),
                            .fixture(
                                id: addedDishId, mealId: $0, name: "味噌汁", quantity: nil,
                                positionInMeal: 1),
                        ]
                    }, unsentDishIds: { _ in [addedDishId] })
                self.estimatedDishId = estimatedDishId
                self.addedDishId = addedDishId
            }

            @Test("推定できた料理は、確かめずに料理だけを消すこと")
            func deletesEstimatedDish() {
                #expect(offer.rowDeletion(of: estimatedDishId) == .dish)
            }

            @Test("足したばかりの料理も1品に数え、確かめずに料理だけを消すこと")
            func deletesAddedDish() {
                #expect(offer.rowDeletion(of: addedDishId) == .dish)
            }
        }

        @Suite("推定中の食事に、料理が1品だけあるとき")
        struct AwaitingEstimation {
            let offer: MealEditOffer
            let dishId: UUID

            init() throws {
                let dishId = UUID()
                offer = try MealEditOfferTests.offer(
                    status: .estimating, dishes: { [.fixture(id: dishId, mealId: $0)] })
                self.dishId = dishId
            }

            @Test("最後の1品でも、料理の行の「削除」を出さないこと")
            func hidesSwipeDeletion() {
                #expect(offer.rowDeletion(of: dishId) == .hidden)
            }

            @Test("最後の1品でも、料理の画面の「この料理を削除」を出さないこと")
            func hidesDeletionOnDishScreen() {
                #expect(offer.dishScreen(dishId: dishId, rejectedLines: [])?.deletion == .hidden)
            }
        }

        @Suite("キャッシュに無い料理のとき")
        struct MissingDish {
            let offer: MealEditOffer
            let missingDishId: UUID

            init() throws {
                offer = try MealEditOfferTests.offer(
                    status: .estimated, dishes: { [.fixture(mealId: $0)] })
                missingDishId = UUID()
            }

            @Test("料理の画面を出さないこと")
            func showsNoDishScreen() {
                #expect(offer.dishScreen(dishId: missingDishId, rejectedLines: []) == nil)
            }

            @Test("料理の行の「削除」は、料理だけを消すこと")
            func deletesDishOnly() {
                #expect(offer.rowDeletion(of: missingDishId) == .dish)
            }
        }
    }
}

extension MealEditOffer.DishScreenOffer {
    /// 押せるかに寄らない量の欄
    fileprivate var quantityField: QuantityField? {
        switch nameAndQuantity {
        case .editable(let quantity), .disabled(let quantity): quantity
        }
    }
}
