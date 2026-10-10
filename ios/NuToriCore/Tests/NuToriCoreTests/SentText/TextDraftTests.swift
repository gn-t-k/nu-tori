import Foundation
import NuToriCore
import Testing

@Suite("入力欄の書く欄")
struct TextDraftTests {
    @Suite("何も書いていないとき")
    struct Empty {
        let draft: TextDraft

        init() {
            draft = TextDraft()
        }

        @Test("送れないこと")
        func cannotSend() {
            #expect(!draft.canSend)
        }

        @Test("プリセットを出すこと")
        func showsPresets() {
            #expect(draft.showsPresets)
        }

        @Test("残りの字数を出さないこと")
        func hidesRemaining() {
            #expect(draft.remainingLength == nil)
        }
    }

    @Suite("空白と改行だけを書いたとき")
    struct OnlyWhitespace {
        let draft: TextDraft

        init() {
            draft = TextDraft(text: " \n　")
        }

        @Test("送れないこと")
        func cannotSend() {
            #expect(!draft.canSend)
        }

        @Test("プリセットを隠すこと")
        func hidesPresets() {
            #expect(!draft.showsPresets)
        }
    }

    @Suite("前後の空白を除いて 450 字のとき")
    struct FourHundredFifty {
        let draft: TextDraft

        init() {
            draft = TextDraft(text: " " + String(repeating: "あ", count: 450) + "\n")
        }

        @Test("送れること")
        func canSend() {
            #expect(draft.canSend)
        }

        @Test("残りの字数をまだ出さないこと")
        func hidesRemaining() {
            #expect(draft.remainingLength == nil)
        }
    }

    @Suite("451 字のとき")
    struct FourHundredFiftyOne {
        let draft: TextDraft

        init() {
            draft = TextDraft(text: String(repeating: "あ", count: 451))
        }

        @Test("残りを 49 字と出すこと")
        func showsRemaining() {
            #expect(draft.remainingLength == 49)
        }
    }

    @Suite("前後の空白を除いて 500 字のとき")
    struct FiveHundred {
        let draft: TextDraft

        init() {
            draft = TextDraft(text: "  " + String(repeating: "あ", count: 500) + " ")
        }

        @Test("送れること")
        func canSend() {
            #expect(draft.canSend)
        }

        @Test("残りを 0 字と出すこと")
        func showsZero() {
            #expect(draft.remainingLength == 0)
        }
    }

    @Suite("501 字のとき")
    struct FiveHundredOne {
        let draft: TextDraft

        init() {
            draft = TextDraft(text: String(repeating: "あ", count: 501))
        }

        @Test("送れないこと")
        func cannotSend() {
            #expect(!draft.canSend)
        }

        @Test("残りを負の数で出すこと")
        func showsNegative() {
            #expect(draft.remainingLength == -1)
        }
    }

    @Suite("見た目の1字が2つのコードポイントの国旗を 251 個書いたとき")
    struct TwoCodePointFlags {
        let draft: TextDraft

        init() {
            // 🇯🇵 は2つのコードポイント（地域の指示記号）で、見た目は1字
            draft = TextDraft(text: String(repeating: "🇯🇵", count: 251))
        }

        @Test("サーバーと同じくコードポイントで数え、送れないこと")
        func cannotSend() {
            #expect(!draft.canSend)
        }

        @Test("残りもコードポイントで数えること")
        func countsRemainingInCodePoints() {
            #expect(draft.remainingLength == -2)
        }
    }

    @Suite("プリセットを押したとき")
    struct PresetInserted {
        var draft: TextDraft

        init() {
            draft = TextDraft()
            draft.insert(.nextMealAdvice)
        }

        @Test("プリセットの文面を書く欄に入れること")
        func insertsText() {
            #expect(draft.text == "次の食事のアドバイスをください。")
        }

        @Test("プリセットを隠すこと")
        func hidesPresets() {
            #expect(!draft.showsPresets)
        }

        @Test("送ったときの出来事に、プリセットの種類と書き換えていないことと字数を載せること")
        func sentEventCarriesPreset() {
            #expect(
                draft.sentEvent
                    == .textSent(preset: .nextMealAdvice, editedPreset: false, length: 16))
        }
    }

    @Suite("プリセットの文面に書き足したとき")
    struct PresetEdited {
        var draft: TextDraft

        init() {
            draft = TextDraft()
            draft.insert(.mealFeedbackSoFar)
            draft.text += "夜は外食です。"
        }

        @Test("送ったときの出来事に、書き換えたことを載せること")
        func sentEventMarksEdited() {
            #expect(
                draft.sentEvent
                    == .textSent(preset: .mealFeedbackSoFar, editedPreset: true, length: 28))
        }
    }

    @Suite("プリセットを押したあと、書く欄を空にして書き直したとき")
    struct PresetClearedAndRewritten {
        var draft: TextDraft

        init() {
            draft = TextDraft()
            draft.insert(.mealFeedbackSoFar)
            draft.text = ""
            draft.text = "朝はトースト"
        }

        @Test("送ったときの出来事に、プリセットを載せないこと")
        func sentEventForgetsPreset() {
            #expect(draft.sentEvent == .textSent(preset: nil, editedPreset: false, length: 6))
        }
    }

    @Suite("プリセットを使わずに書いたとき")
    struct WrittenWithoutPreset {
        let draft: TextDraft

        init() {
            draft = TextDraft(text: "  朝はトースト\n")
        }

        @Test("送ったときの出来事に、前後の空白を除いた字数だけを載せること")
        func sentEventCarriesLength() {
            #expect(draft.sentEvent == .textSent(preset: nil, editedPreset: false, length: 6))
        }
    }
}
