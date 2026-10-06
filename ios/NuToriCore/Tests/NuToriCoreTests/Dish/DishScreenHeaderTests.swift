import Foundation
import NuToriCore
import Testing

@Suite("料理の画面の名前と量")
struct DishScreenHeaderTests {
    static func header(
        quantity: Dish.Quantity?, progress: DishProgress = .settled
    ) -> DishScreenHeader {
        DishScreenHeader(
            DishContents(dish: .fixture(quantity: quantity), ingredients: [], progress: progress))
    }

    static let estimated = Dish.Quantity(value: 1, unit: "杯", source: .estimated)
    static let corrected = Dish.Quantity(value: 1.5, unit: "杯", source: .corrected)

    @Suite("量の欄")
    struct QuantityField {
        @Test("推定したままの量は、数だけを欄に入れ、単位を添えて推定の印を付けること")
        func estimatedQuantity() throws {
            let field = try #require(
                DishScreenHeaderTests.header(
                    quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .estimated)
                ).quantityField)

            #expect(field.text == "1.5")
            #expect(field.unit == "杯")
            #expect(field.showsEstimateBadge)
        }

        @Test("直した量には推定の印を付けないこと")
        func correctedQuantity() throws {
            let field = try #require(
                DishScreenHeaderTests.header(quantity: DishScreenHeaderTests.corrected)
                    .quantityField)

            #expect(field.text == "1.5")
            #expect(!field.showsEstimateBadge)
        }

        @Test("待っている料理の推定したままの量は、食事の画面の料理の行と同じく欄を空けて「—」にすること")
        func waitingDishWithEstimatedQuantity() throws {
            let field = try #require(
                DishScreenHeaderTests.header(
                    quantity: DishScreenHeaderTests.estimated, progress: .estimating
                ).quantityField)

            #expect(field.text == "")
            #expect(field.placeholder == "—")
            #expect(!field.showsEstimateBadge)
        }

        @Test("待っている料理でも、直してある量は欄に入れること")
        func waitingDishWithCorrectedQuantity() throws {
            let field = try #require(
                DishScreenHeaderTests.header(
                    quantity: DishScreenHeaderTests.corrected, progress: .deferredToNextDay
                ).quantityField)

            #expect(field.text == "1.5")
        }

        @Test("量の無い料理には量の欄を出さないこと")
        func withoutQuantity() {
            #expect(
                DishScreenHeaderTests.header(quantity: nil, progress: .notSent).quantityField
                    == nil)
        }
    }

    @Suite("名前と量の下の注記")
    struct Note {
        @Test("名前の欄を選んでいないときは、量を変えると材料も同じ割合で変わることを書くこと")
        func notEditingName() {
            #expect(
                DishScreenHeaderTests.header(quantity: DishScreenHeaderTests.estimated)
                    .note(editingName: false) == "量を変えると、材料の量も同じ割合で変わります。")
        }

        @Test("名前の欄を選んでいて量が推定したままなら、量と材料を推定し直すことを書くこと")
        func editingNameWithEstimatedQuantity() {
            #expect(
                DishScreenHeaderTests.header(quantity: DishScreenHeaderTests.estimated)
                    .note(editingName: true) == "名前を変えると、量と材料を推定し直します。")
        }

        @Test("名前の欄を選んでいて量を直してあるなら、量はそのままで材料を推定し直すことを書くこと")
        func editingNameWithCorrectedQuantity() {
            #expect(
                DishScreenHeaderTests.header(quantity: DishScreenHeaderTests.corrected)
                    .note(editingName: true) == "名前を変えると、材料を推定し直します。量はそのままです。")
        }

        @Test("量の無い料理は、名前の欄を選んでいないときは注記を出さず、選んでいれば量と材料を推定し直すことを書くこと")
        func withoutQuantity() {
            let header = DishScreenHeaderTests.header(quantity: nil, progress: .notSent)

            #expect(header.note(editingName: false) == nil)
            #expect(header.note(editingName: true) == "名前を変えると、量と材料を推定し直します。")
        }
    }
}
