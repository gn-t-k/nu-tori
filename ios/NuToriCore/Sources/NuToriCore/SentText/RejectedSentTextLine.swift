import Foundation

/// サーバーが受け付けなかった送った文章の書き込みを、タイムラインに一時的に出す1行。
/// どの1行かは書き込みの種類で決め、置き場は1行が決める（作る書き込みは吹き出しを外した位置、送り直す2つは吹き出しの下）
public struct RejectedSentTextLine: Hashable, Sendable {
    /// 端末で見せていた送った文章。作る書き込みの行の本文は、受け付けなかった文がサーバーに残らないので、送り待ちから出す
    public let sentText: SentText
    public let subject: Subject

    public init(sentText: SentText, subject: Subject) {
        self.sentText = sentText
        self.subject = subject
    }

    /// 受け付けなかった書き込み
    public enum Subject: Hashable, Sendable {
        /// 文章を送る（作る書き込み）
        case send
        case resendAsConversation
        case resend
    }

    public enum Placement: Equatable, Sendable {
        /// サーバーに文章が無いので、吹き出しを外した位置（送った時刻）
        case insteadOfBubble
        /// サーバーの値に戻した吹き出しのすぐ下
        case belowBubble
    }

    public var placement: Placement {
        switch subject {
        case .send: .insteadOfBubble
        case .resendAsConversation, .resend: .belowBubble
        }
    }

    public var text: String {
        switch subject {
        case .send:
            let clock = WeightAmountText.clock(
                ClockTime(containing: sentText.sentAt, in: sentText.timeZone))
            return "\(clock) の「\(Self.opening(of: sentText.body))」は、送れませんでした。"
        case .resendAsConversation:
            return "会話として送り直せませんでした。"
        case .resend:
            return "送り直せませんでした。"
        }
    }

    /// 本文の最初の 15 字。15 字以下なら全文で、… を付けない。
    /// 画面に見せる字なので、絵文字や結合文字を途中で切らないよう、見た目の1字（Character）で数える
    private static func opening(of body: String) -> String {
        let shownLength = 15
        return body.count > shownLength ? "\(body.prefix(shownLength))…" : body
    }
}
