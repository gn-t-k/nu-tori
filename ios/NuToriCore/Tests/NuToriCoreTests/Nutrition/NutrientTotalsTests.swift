import Foundation
import NuToriCore
import Testing

@Suite("栄養の合計")
struct NutrientTotalsTests {
    @Suite("材料の合計")
    struct OfIngredients {
        @Suite("すべての材料の値が分かる栄養")
        struct AllKnown {
            let totals: NutrientTotals

            init() {
                totals = NutrientTotals(ingredients: [
                    .fixture(quantity: 100, nutrients: [.energyKcal: 200, .proteinG: 20]),
                    .fixture(quantity: 50, nutrients: [.energyKcal: 100, .proteinG: 4]),
                ])
            }

            @Test("足した値になること")
            func sumsKnownValues() {
                #expect(totals[.energyKcal] == .exactly(250))
                #expect(totals[.proteinG] == .exactly(22))
            }
        }

        @Suite("不明の材料が混じる栄養")
        struct UnknownMixed {
            let totals: NutrientTotals

            init() {
                totals = NutrientTotals(ingredients: [
                    .fixture(quantity: 100, nutrients: [.energyKcal: 200, .fiberG: 3]),
                    .fixture(quantity: 100, nutrients: [.energyKcal: 100]),
                ])
            }

            @Test("分かる分だけを足して「以上」になること")
            func isAtLeast() {
                #expect(totals[.energyKcal] == .exactly(300))
                #expect(totals[.fiberG] == .atLeast(3))
            }
        }

        @Suite("すべての材料が不明の栄養")
        struct AllUnknown {
            let totals: NutrientTotals

            init() {
                totals = NutrientTotals(ingredients: [
                    .fixture(nutrients: [.energyKcal: 200]),
                    .fixture(nutrients: [.energyKcal: 100]),
                ])
            }

            @Test("不明になること")
            func isUnknown() {
                #expect(totals[.fiberG] == .unknown)
            }
        }

        @Suite("値が 0 の材料と不明の材料が混じる栄養")
        struct ZeroAndUnknownMixed {
            let totals: NutrientTotals

            init() {
                totals = NutrientTotals(ingredients: [
                    .fixture(nutrients: [.fiberG: 0]),
                    .fixture(nutrients: [:]),
                ])
            }

            @Test("0 以上になること")
            func isAtLeastZero() {
                #expect(totals[.fiberG] == .atLeast(0))
            }
        }

        @Suite("材料の kcal が、たんぱく質・脂質・炭水化物から出す値と食い違うとき")
        struct EnergyDiffersFromMacros {
            let totals: NutrientTotals

            init() {
                // 4×10 + 9×5 + 4×20 = 165 kcal に当たる P・F・C だが、材料の kcal は 100（アルコールの分などで食い違う）
                totals = NutrientTotals(ingredients: [
                    .fixture(
                        quantity: 100,
                        nutrients: [.energyKcal: 100, .proteinG: 10, .fatG: 5, .carbohydrateG: 20])
                ])
            }

            @Test("kcal は材料の kcal の和で、出し直さないこと")
            func energyIsSumOfIngredientEnergy() {
                #expect(totals[.energyKcal] == .exactly(100))
            }
        }

        @Suite("材料が無いとき")
        struct NoIngredients {
            let totals = NutrientTotals(ingredients: [])

            @Test("どの栄養も 0 になること")
            func isZero() {
                #expect(totals[.energyKcal] == .exactly(0))
                #expect(totals[.proteinG] == .exactly(0))
            }
        }
    }

    @Suite("合計どうしを足すとき")
    struct Combining {
        static let known = NutrientTotals(ingredients: [.fixture(nutrients: [.fiberG: 10])])
        static let partial = NutrientTotals(ingredients: [
            .fixture(nutrients: [.fiberG: 5]), .fixture(nutrients: [:]),
        ])
        static let unknown = NutrientTotals(ingredients: [.fixture(nutrients: [:])])

        @Suite("分かる合計どうし")
        struct KnownPlusKnown {
            let totals = NutrientTotals(combining: [Combining.known, Combining.known])

            @Test("足した値になること")
            func sums() {
                #expect(totals[.fiberG] == .exactly(20))
            }
        }

        @Suite("「以上」の合計が混じるとき")
        struct WithAtLeast {
            let totals = NutrientTotals(combining: [Combining.known, Combining.partial])
            let flat = NutrientTotals(ingredients: [
                .fixture(nutrients: [.fiberG: 10]), .fixture(nutrients: [.fiberG: 5]),
                .fixture(nutrients: [:]),
            ])

            @Test("「以上」になること")
            func isAtLeast() {
                #expect(totals[.fiberG] == .atLeast(15))
            }

            @Test("材料から直に出した合計と同じになること")
            func isSameAsFlat() {
                #expect(totals == flat)
            }
        }

        @Suite("不明の合計が分かる合計と混じるとき")
        struct UnknownMixedWithKnown {
            let totals = NutrientTotals(combining: [Combining.unknown, Combining.known])

            @Test("「以上」になること")
            func isAtLeast() {
                #expect(totals[.fiberG] == .atLeast(10))
            }
        }

        @Suite("不明の合計だけのとき")
        struct UnknownOnly {
            let totals = NutrientTotals(combining: [Combining.unknown, Combining.unknown])

            @Test("不明のままになること")
            func isUnknown() {
                #expect(totals[.fiberG] == .unknown)
            }
        }
    }
}
