#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: DailyGuideChangeNoticeCard.Sample.allCases) { sample in
        DailyGuideChangeNoticeCard(notice: sample.notice, openGoal: {})
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    extension DailyGuideChangeNoticeCard {
        fileprivate enum Sample: CaseIterable {
            /// 推定消費カロリーが下がって、1日の目安が 30 kcal 下がった
            case expenditureDecreased

            var notice: DailyGuideChangeNotice {
                DailyGuideChangeNotice(
                    review: .sampleReviewed, dailyGuide: .sampleReviewed,
                    changeKilocalories: -30,
                    reason: .expenditureChanged(fromKilocalories: 2190, toKilocalories: 2140))
            }
        }
    }
#endif
