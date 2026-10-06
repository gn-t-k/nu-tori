import Foundation
import NuToriCore
import Testing

@Suite("料理と材料の量の欄の文字")
struct QuantityFieldTextTests {
    @Test("欄には数だけを、小数1桁まで（整数なら小数点なし）で入れること")
    func text() {
        #expect(QuantityFieldText.text(2) == "2")
        #expect(QuantityFieldText.text(1.5) == "1.5")
        #expect(QuantityFieldText.text(142.5) == "142.5")
        #expect(QuantityFieldText.text(190.04) == "190")
    }

    @Test("打った文字を数として読み、小数点の「,」と末尾の小数点も受け付けること")
    func typed() {
        #expect(QuantityFieldText.value(typed: "150") == 150)
        #expect(QuantityFieldText.value(typed: "1.5") == 1.5)
        #expect(QuantityFieldText.value(typed: "1,5") == 1.5)
        #expect(QuantityFieldText.value(typed: "2.") == 2)
    }

    @Test("空の欄と数でない文字は読まないこと")
    func notNumber() {
        #expect(QuantityFieldText.value(typed: "") == nil)
        #expect(QuantityFieldText.value(typed: ".") == nil)
        #expect(QuantityFieldText.value(typed: "1.2.3") == nil)
    }
}
