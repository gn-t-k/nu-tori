#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: WeeklyReviewCardView.Sample.allCases) { sample in
        if let card = sample.card {
            WeeklyReviewCardView(card: card, open: {})
                .padding()
                .background(Color(.systemGroupedBackground))
        }
    }

    extension WeeklyReviewCardView {
        fileprivate enum Sample: CaseIterable {
            /// 1週目を見直した。7日の丸（使い始めた月曜から）とペースの1行
            case reviewed
            /// 食事の記録が少なくて見送った。「1日の目安はそのままです。」を足す
            case deferred

            var card: WeeklyReviewCard? {
                let timeline = WeeklyReviewPreviewScene.timeline(deferred: self == .deferred)
                return timeline.days.lazy.flatMap(\.items).compactMap { item in
                    if case .weeklyReviewCard(let card) = item { card } else { nil }
                }.first
            }
        }
    }
#endif
