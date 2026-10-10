import Foundation
import NuToriCore
import Testing

@Suite("返事の書式")
struct ReplyTextTests {
    @Test("空行で段落を分け、段落の中の改行は残すこと")
    func splitsParagraphs() {
        let text = ReplyText("今日は 1,420 kcal です。\n昼が多めでした。\n\n夜は軽めにしましょう。")

        #expect(
            text.lines == [
                .init(.paragraph, [.plain("今日は 1,420 kcal です。\n昼が多めでした。")]),
                .init(.paragraph, [.plain("夜は軽めにしましょう。")]),
            ])
    }

    @Test("「- 」と「* 」で始まる行を箇条書きに、「1. 」で始まる行を番号つきの箇条書きにすること")
    func readsLists() {
        let text = ReplyText("候補です。\n- 焼き魚定食\n* 冷奴\n1. 野菜から食べる\n2. ご飯は小盛り")

        #expect(
            text.lines == [
                .init(.paragraph, [.plain("候補です。")]),
                .init(.bullet, [.plain("焼き魚定食")]),
                .init(.bullet, [.plain("冷奴")]),
                .init(.numbered(1), [.plain("野菜から食べる")]),
                .init(.numbered(2), [.plain("ご飯は小盛り")]),
            ])
    }

    @Test("「**」で囲んだところを太字にすること")
    func readsBold() {
        let text = ReplyText("P は **38 g** で、目安の **半分** です。")

        #expect(
            text.lines == [
                .init(
                    .paragraph,
                    [
                        .plain("P は "), .bold("38 g"), .plain(" で、目安の "), .bold("半分"),
                        .plain(" です。"),
                    ])
            ])
    }

    @Test("伸びている途中で閉じていない「**」は記号を見せず、そこから先を太字にすること")
    func readsUnclosedBoldWhileGrowing() {
        let text = ReplyText("P は **38")

        #expect(text.lines == [.init(.paragraph, [.plain("P は "), .bold("38")])])
    }

    @Test("箇条書きの中の太字も読むこと")
    func readsBoldInList() {
        let text = ReplyText("- **鮭** の塩焼き")

        #expect(text.lines == [.init(.bullet, [.bold("鮭"), .plain(" の塩焼き")])])
    }
}
