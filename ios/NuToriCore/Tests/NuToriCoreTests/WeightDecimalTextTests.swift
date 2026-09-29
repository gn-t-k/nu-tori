import NuToriCore
import Testing

@Suite("体重のキーボード入力")
struct WeightDecimalTextTests {
    @Suite("小数第2位を打ったとき")
    struct SecondDecimalDigit {
        @Test("小数第1位まで残すこと")
        func keepsOneDecimalPlace() {
            #expect(WeightDecimalText.sanitized("72.45") == "72.4")
        }
    }

    @Suite("コンマを打ったとき")
    struct CommaSeparator {
        @Test("小数点として読むこと")
        func readsCommaAsDecimalPoint() {
            #expect(WeightDecimalText.sanitized("72,4") == "72.4")
        }
    }

    @Suite("小数点を2つ打ったとき")
    struct TwoSeparators {
        @Test("2つ目を落とすこと")
        func dropsTheSecondSeparator() {
            #expect(WeightDecimalText.sanitized("72.4.9") == "72.4")
        }
    }

    @Suite("整数を5桁打ったとき")
    struct FiveIntegerDigits {
        @Test("4桁まで残すこと")
        func keepsFourDigits() {
            #expect(WeightDecimalText.sanitized("10000") == "1000")
        }
    }

    @Suite("小数点で終えたとき")
    struct TrailingSeparator {
        @Test("小数点を残すこと")
        func keepsTheSeparator() {
            #expect(WeightDecimalText.sanitized("20.") == "20.")
        }
    }
}
