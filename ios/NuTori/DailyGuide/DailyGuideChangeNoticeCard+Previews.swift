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
            /// 3週分をまとめて見直した
            case batch

            var notice: DailyGuideChangeNotice {
                DailyGuideChangeNotice(
                    review: .sampleReviewed, dailyGuide: .sampleReviewed,
                    changeKilocalories: -30,
                    reason: .expenditureChanged(fromKilocalories: 2190, toKilocalories: 2140),
                    batch: self == .batch
                        ? DailyGuideChangeNotice.Batch(
                            firstWeekMonday: CalendarDay(year: 2026, month: 8, day: 31),
                            weekCount: 3)
                        : nil)
            }
        }
    }
#endif
