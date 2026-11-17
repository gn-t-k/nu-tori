import NuToriCore
import Testing

@Suite("料理の名前の欄に入れる文字")
struct DishTests {
    @Suite("名前の欄に、上限の 100 字までの文字を打ったとき")
    struct TypingNameWithinLimit {
        let text: String

        init() {
            text = Dish.nameFieldText(typed: String(repeating: "あ", count: 100))
        }

        @Test("打ったとおりに入れること")
        func keeps() {
            #expect(text == String(repeating: "あ", count: 100))
        }
    }

    @Suite("名前の欄に、上限より長い文字を貼ったとき")
    struct PastingTooLongName {
        let text: String

        init() {
            text = Dish.nameFieldText(typed: String(repeating: "あ", count: 99) + "いう")
        }

        @Test("先頭の 100 字までを入れること")
        func clips() {
            #expect(text == String(repeating: "あ", count: 99) + "い")
        }
    }

    // 家族の絵文字は、7 つのコードポイントでできた1字
    @Suite("名前の欄に、上限をまたぐ絵文字を打ったとき")
    struct TypingEmojiAcrossLimit {
        let text: String

        init() {
            text = Dish.nameFieldText(typed: String(repeating: "あ", count: 95) + "👨‍👩‍👧‍👦")
        }

        @Test("絵文字の途中で切らず、絵文字ごと入れないこと")
        func dropsWholeCharacter() {
            #expect(text == String(repeating: "あ", count: 95))
        }
    }
}
