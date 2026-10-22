#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI
    import UIKit

    #Preview("状態ごと", arguments: SentTextBubbleView.Sample.allCases) { sample in
        SentTextBubbleView(
            bubble: sample.bubble, isUndelivered: sample.isUndelivered,
            regeneration: sample.regeneration,
            isMealUndelivered: { _ in sample.isMealUndelivered },
            openMeal: { _ in },
            loadPhoto: { _, photoId in UIImage.sampleMealPhoto(for: photoId) }
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
            /// 返事が届いた（返事は吹き出しの下に別に並ぶ）。文章の食事がすべて消えたときも、吹き出しだけのこの形
            case replied
            /// 食事が1つできた
            case oneMeal
            /// 食事が1つできて、食事の画面で直したのがまだ届いていない。食事の行だけを薄く描く
            case oneMealUndelivered
            /// 食事が3つできた。前の日の夜と今朝の食事は、送った時刻と食べた時刻が違う
            case mealsAtDifferentTimes
            /// やり直しを使い切った
            case failedRetriesExhausted
            /// 提供元が受け付けなかった（400）
            case failedBadRequest
            /// その日の回数切れ
            case halted
            /// 送り直すを受け付けなかった
            case resendRejected
            /// サブスクリプション切れで止めた。切れているあいだは送り直すを出さない
            case haltedBySubscription
            /// 食事が1つできたが、サブスクリプション切れのあいだ。会話として送り直すを出さない
            case oneMealWhileSubscriptionExpired

            var bubble: SentTextBubble {
                switch self {
                case .undelivered, .replied:
                    SentTextBubble(
                        sentText: Self.sentText, meals: [], replyLine: nil, rejectedLine: nil)
                case .reading:
                    SentTextBubble(
                        sentText: Self.sentText, meals: [], replyLine: .reading, rejectedLine: nil)
                case .failedRetriesExhausted:
                    SentTextBubble(
                        sentText: Self.sentText, meals: [], replyLine: .failed(.retriesExhausted),
                        rejectedLine: nil)
                case .failedBadRequest:
                    SentTextBubble(
                        sentText: Self.sentText, meals: [], replyLine: .failed(.badRequest),
                        rejectedLine: nil)
                case .oneMeal, .oneMealUndelivered, .oneMealWhileSubscriptionExpired:
                    SentTextBubble(
                        sentText: Self.mealText, meals: [Self.lunch], replyLine: nil,
                        rejectedLine: nil)
                case .mealsAtDifferentTimes:
                    SentTextBubble(
                        sentText: Self.mealText,
                        meals: [
                            MealCard(
                                meal: .sampleWritten(
                                    from: Self.mealText,
                                    eatenOn: CalendarDay.sampleToday.advanced(by: -1), at: 19, 0),
                                status: .estimating, recordedOnThisDevice: false),
                            .sampleEstimated(
                                .sampleWritten(
                                    from: Self.mealText, eatenOn: .sampleToday, at: 7, 30)),
                            Self.lunch,
                        ],
                        replyLine: nil, rejectedLine: nil)
                case .halted:
                    SentTextBubble(
                        sentText: Self.sentText, meals: [], replyLine: .halted(.dailyLimit),
                        rejectedLine: nil)
                case .haltedBySubscription:
                    SentTextBubble(
                        sentText: Self.sentText, meals: [],
                        replyLine: .halted(.subscriptionExpired), rejectedLine: nil)
                case .resendRejected:
                    SentTextBubble(
                        sentText: Self.sentText, meals: [], replyLine: .failed(.retriesExhausted),
                        rejectedLine: RejectedSentTextLine(
                            sentText: Self.sentText, subject: .resend))
                }
            }

            var regeneration: SentTextBubbleView.Regeneration {
                switch self {
                case .haltedBySubscription, .oneMealWhileSubscriptionExpired: .unavailable
                case .undelivered, .reading, .replied, .oneMeal, .oneMealUndelivered,
                    .mealsAtDifferentTimes, .failedRetriesExhausted, .failedBadRequest, .halted,
                    .resendRejected:
                    .available(resend: { _ in }, resendAsConversation: {})
                }
            }

            var isUndelivered: Bool {
                self == .undelivered
            }

            var isMealUndelivered: Bool {
                self == .oneMealUndelivered
            }

            private static let mealText = SentText.sample(
                "昨日の夜はカレー、朝はパン、昼はうどん", on: .sampleToday, at: 12, 0)

            private static let lunch = MealCard.sampleEstimated(
                .sampleWritten(from: mealText, eatenOn: .sampleToday, at: 12, 0))

            private static let sentText = SentText(
                id: UUID(), body: "次の食事のアドバイスをください。",
                sentAt: Meal.sample(on: .sampleToday, at: 12, 10).sentAt,
                timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        }
    }
#endif
