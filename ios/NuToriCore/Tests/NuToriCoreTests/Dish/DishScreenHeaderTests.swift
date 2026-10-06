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
        @Suite("推定したままの量のとき")
        struct Estimated {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(
                    quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .estimated))
            }

            @Test("数だけを欄に入れ、単位を添えて推定の印を付けること")
            func showsNumberWithBadge() throws {
                let field = try #require(header.quantityField)

                #expect(field.text == "1.5")
                #expect(field.unit == "杯")
                #expect(field.showsEstimateBadge)
            }
        }

        @Suite("直した量のとき")
        struct Corrected {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(quantity: DishScreenHeaderTests.corrected)
            }

            @Test("推定の印を付けないこと")
            func showsNoBadge() throws {
                let field = try #require(header.quantityField)

                #expect(field.text == "1.5")
                #expect(!field.showsEstimateBadge)
            }
        }

        @Suite("待っている料理の推定したままの量のとき")
        struct WaitingWithEstimated {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(
                    quantity: DishScreenHeaderTests.estimated, progress: .estimating)
            }

            @Test("食事の画面の料理の行と同じく欄を空けて「—」にすること")
            func showsDash() throws {
                let field = try #require(header.quantityField)

                #expect(field.text == "")
                #expect(field.placeholder == "—")
                #expect(!field.showsEstimateBadge)
            }
        }

        @Suite("待っている料理の直してある量のとき")
        struct WaitingWithCorrected {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(
                    quantity: DishScreenHeaderTests.corrected, progress: .deferredToNextDay)
            }

            @Test("欄に入れること")
            func showsCorrectedQuantity() throws {
                let field = try #require(header.quantityField)

                #expect(field.text == "1.5")
            }
        }

        @Suite("量の無い料理のとき")
        struct WithoutQuantity {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(quantity: nil, progress: .notSent)
            }

            @Test("量の欄を出さないこと")
            func hidesField() {
                #expect(header.quantityField == nil)
            }
        }
    }

    @Suite("名前と量の下の注記")
    struct Note {
        @Suite("推定したままの量のとき")
        struct Estimated {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(quantity: DishScreenHeaderTests.estimated)
            }

            @Test("名前の欄を選んでいないときは、量を変えると材料も同じ割合で変わることを書くこと")
            func notEditingName() {
                #expect(header.note(editingName: false) == "量を変えると、材料の量も同じ割合で変わります。")
            }

            @Test("名前の欄を選んでいれば、量と材料を推定し直すことを書くこと")
            func editingName() {
                #expect(header.note(editingName: true) == "名前を変えると、量と材料を推定し直します。")
            }
        }

        @Suite("直した量のとき")
        struct Corrected {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(quantity: DishScreenHeaderTests.corrected)
            }

            @Test("名前の欄を選んでいれば、量はそのままで材料を推定し直すことを書くこと")
            func editingName() {
                #expect(
                    header.note(editingName: true) == "名前を変えると、材料を推定し直します。量はそのままです。")
            }
        }

        @Suite("量の無い料理のとき")
        struct WithoutQuantity {
            let header: DishScreenHeader

            init() {
                header = DishScreenHeaderTests.header(quantity: nil, progress: .notSent)
            }

            @Test("名前の欄を選んでいないときは、注記を出さないこと")
            func notEditingName() {
                #expect(header.note(editingName: false) == nil)
            }

            @Test("名前の欄を選んでいれば、量と材料を推定し直すことを書くこと")
            func editingName() {
                #expect(header.note(editingName: true) == "名前を変えると、量と材料を推定し直します。")
            }
        }
    }
}
