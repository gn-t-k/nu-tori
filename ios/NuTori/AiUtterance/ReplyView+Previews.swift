#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI
    import UIKit

    #Preview("状態ごと", arguments: ReplyView.Sample.allCases) { sample in
        ReplyView(
            reply: sample.reply, openMeal: { _ in },
            loadPhoto: { _, photoId in UIImage.sampleMealPhoto(for: photoId) }
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    extension ReplyView {
        fileprivate enum Sample: CaseIterable {
            /// 段落・太字・箇条書き・番号つきの箇条書き
            case formatted
            /// 見守る要求で伸びている途中。文字ずつ出す
            case growing
            /// 指し示す食事が、写真の食事・消えた食事の順に並ぶ
            case referencingMeals

            var reply: TimelineReply {
                switch self {
                case .formatted:
                    TimelineReply(
                        id: UUID(), sentTextId: UUID(),
                        body: """
                            今日はここまで **1,420 kcal** です。P が少なめでした。

                            - 夜は焼き魚定食
                            - ご飯は小盛り

                            1. 野菜から食べる
                            2. 汁物を足す
                            """,
                        isGrowing: false, referencedMeals: [])
                case .growing:
                    TimelineReply(
                        id: UUID(), sentTextId: UUID(), body: "野菜の多い定食はどうでしょう。鮭の塩焼きなら",
                        isGrowing: true, referencedMeals: [])
                case .referencingMeals:
                    TimelineReply(
                        id: UUID(), sentTextId: UUID(), body: "この2つの食事のことですね。",
                        isGrowing: false,
                        referencedMeals: [
                            .meal(.sampleEstimated(.sample(on: .sampleToday, at: 12, 20))),
                            .deleted(mealId: UUID()),
                        ])
                }
            }
        }
    }
#endif
