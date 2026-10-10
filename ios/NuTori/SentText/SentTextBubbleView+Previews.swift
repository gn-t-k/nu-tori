#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: SentTextBubbleView.Sample.allCases) { sample in
        SentTextBubbleView(
            bubble: sample.bubble, isUndelivered: sample.isUndelivered, resend: { _ in }
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    extension SentTextBubbleView {
        fileprivate enum Sample: CaseIterable {
            /// まだ届いていない。吹き出しを薄く描き、回る印は出さない
            case undelivered
            /// 届いて、読み分けか返事の最初の文字を待っている
            case reading
            /// 返事が届いた（返事は吹き出しの下に別に並ぶ）
            case replied
            /// やり直しを使い切った
            case failedRetriesExhausted
            /// 提供元が受け付けなかった（400）
            case failedBadRequest
            /// その日の回数切れ
            case halted
            /// 送り直すを受け付けなかった
            case resendRejected

            var bubble: SentTextBubble {
                switch self {
                case .undelivered, .replied:
                    SentTextBubble(sentText: Self.sentText, replyLine: nil, rejectedLine: nil)
                case .reading:
                    SentTextBubble(sentText: Self.sentText, replyLine: .reading, rejectedLine: nil)
                case .failedRetriesExhausted:
                    SentTextBubble(
                        sentText: Self.sentText, replyLine: .failed(.retriesExhausted),
                        rejectedLine: nil)
                case .failedBadRequest:
                    SentTextBubble(
                        sentText: Self.sentText, replyLine: .failed(.badRequest), rejectedLine: nil)
                case .halted:
                    SentTextBubble(sentText: Self.sentText, replyLine: .halted, rejectedLine: nil)
                case .resendRejected:
                    SentTextBubble(
                        sentText: Self.sentText, replyLine: .failed(.retriesExhausted),
                        rejectedLine: RejectedSentTextLine(
                            sentText: Self.sentText, subject: .resend))
                }
            }

            var isUndelivered: Bool {
                self == .undelivered
            }

            private static let sentText = SentText(
                id: UUID(), body: "次の食事のアドバイスをください。",
                sentAt: Meal.sample(on: .sampleToday, at: 12, 10).sentAt,
                timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        }
    }
#endif
