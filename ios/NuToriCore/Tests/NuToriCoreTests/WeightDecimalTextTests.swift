import NuToriCore
import Testing

@Suite("体重のキーボード入力")
struct WeightDecimalTextTests {
    @Suite("小数第2位を打ったとき")
    struct SecondDecimalDigit {
        let typed: String

        init() {
            typed = "72.45"
        }

        @Test("小数第1位まで残すこと")
        func keepsOneDecimalPlace() {
            #expect(WeightDecimalText.sanitized(typed) == "72.4")
        }
    }

    @Suite("コンマを打ったとき")
    struct CommaSeparator {
        let typed: String

        init() {
            typed = "72,4"
        }

        @Test("小数点として読むこと")
        func readsCommaAsDecimalPoint() {
            #expect(WeightDecimalText.sanitized(typed) == "72.4")
        }
    }

    @Suite("小数点を2つ打ったとき")
    struct TwoSeparators {
        let typed: String

        init() {
            typed = "72.4.9"
        }

        @Test("2つ目を落とすこと")
        func dropsTheSecondSeparator() {
            #expect(WeightDecimalText.sanitized(typed) == "72.4")
        }
    }

    @Suite("整数を5桁打ったとき")
    struct FiveIntegerDigits {
        let typed: String

        init() {
            typed = "10000"
        }

        @Test("4桁まで残すこと")
        func keepsFourDigits() {
            #expect(WeightDecimalText.sanitized(typed) == "1000")
        }
    }

    @Suite("小数点で終えたとき")
    struct TrailingSeparator {
        let typed: String

        init() {
            typed = "20."
        }

        @Test("小数点を残すこと")
        func keepsTheSeparator() {
            #expect(WeightDecimalText.sanitized(typed) == "20.")
        }
    }
}
