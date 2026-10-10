import Foundation
import NuToriCore
import SwiftUI

/// 送った文章の吹き出し（DESIGN.md の own-message-bubble）と、その下に添える1行。
/// 応答待ちの回る印と「読んでいます…」は返事が来る場所（左の地の上）に、作れなかった・回数切れの1行と「送り直す」は右下に置く
struct SentTextBubbleView: View {
    let bubble: SentTextBubble
    /// まだ届いていない文章。吹き出しを薄く描く
    let isUndelivered: Bool
    let resend: (ClientUsageEvent.ReplyRegenerateReason) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(bubble.sentText.body)
                    // 会話の文字は Body（自分の吹き出しも返事も）。仕様 #419「少しずつ伸びる返事」
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18))
                    .undeliveredRecord(isUndelivered)
                    .accessibilityIdentifier("sent-text-bubble")
            }
            .containerRelativeFrame(.horizontal) { width, _ in
                let widthRatio: CGFloat = 0.78
                return width * widthRatio
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            if let rejected = bubble.rejectedLine {
                Text(rejected.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("rejected-sent-text-line")
            }
            if let line = bubble.replyLine {
                replyLine(line)
            }
        }
    }

    @ViewBuilder private func replyLine(_ line: SentTextBubble.ReplyLine) -> some View {
        switch line {
        case .reading:
            // 送った文章の応答待ちの待っている表示。食事とも会話とも取れる文言にする
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(line.text)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("reply-reading")
        case .halted, .failed:
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(line.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("reply-failed-line")
                Button("送り直す") {
                    resend(Self.reason(of: line))
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("reply-resend")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private static func reason(of line: SentTextBubble.ReplyLine)
        -> ClientUsageEvent.ReplyRegenerateReason
    {
        switch line {
        case .failed(let reason): .failed(reason)
        case .halted, .reading: .halted
        }
    }
}
