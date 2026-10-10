import Foundation

/// 入力欄の書く欄に書きかけの文。送れるか、残りの字数を出すか、プリセットを出すか、送ったときの出来事を決める
public struct TextDraft: Equatable, Sendable {
    /// 書く欄の文。打ったとおりに持ち、前後の空白は送るときに除く。空にしたら、押したプリセットを忘れる
    public var text: String {
        didSet {
            if text.isEmpty {
                insertedPreset = nil
            }
        }
    }

    public init(text: String = "") {
        self.text = text
    }

    /// 前後の空白を除いて 1〜500 字のときだけ送れる。空白だけや長すぎるときも、書くことは止めない
    public var canSend: Bool {
        SentText.acceptedBody(typed: text) != nil
    }

    /// プリセットは、書く欄に文字があるあいだ隠す（押すと書きかけの文を置き換えてしまうため）
    public var showsPresets: Bool { text.isEmpty }

    /// 書く欄の下に出す「残り N」の N。450 字を超えるまでは nil で、500 字を超えたら負の数
    public var remainingLength: Int? {
        let upperBound = Int(AcceptedRange.sentTextBodyTrimmedLength.bounds.upperBound)
        let remaining = upperBound - trimmedLength
        return remaining < Self.remainingShownBelow ? remaining : nil
    }

    /// 送ったときに PostHog に送る出来事。本文は載せない
    public var sentEvent: ClientUsageEvent {
        .textSent(
            preset: insertedPreset,
            editedPreset: insertedPreset.map { $0.text != text } ?? false,
            length: trimmedLength)
    }

    /// プリセットの文面を書く欄に入れる。プリセットは書く欄が空のときだけ出すので、書きかけの文を置き換えることは無い
    public mutating func insert(_ preset: TextPreset) {
        text = preset.text
        insertedPreset = preset
    }

    /// 書く欄を空にするまで覚えておく、押したプリセット
    private var insertedPreset: TextPreset?

    /// 残りがこの字数を下回ったら（451 字目から）出す
    private static let remainingShownBelow = 50

    /// 前後の空白を除いた字の数。サーバーと同じ数になるよう、Unicode のコードポイントで数える
    private var trimmedLength: Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count
    }
}
