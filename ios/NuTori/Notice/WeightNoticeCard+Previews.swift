#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: WeightNoticeCard.Sample.allCases) { sample in
        WeightNoticeCard(
            card: sample.card,
            records: sample.records,
            today: .sampleToday,
            now: { .now },
            capture: { _ in },
            onRecord: { _ in }
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    extension WeightNoticeCard {
        fileprivate enum Sample: CaseIterable {
            /// 今日の答えていない知らせ。前回の値から始まるステッパーと「記録」
            case awaitingAnswer
            /// 今日の答えていない知らせで、体重記録がまだ1つも無い。値は空で、押すとキーボードで入れる
            case awaitingAnswerWithoutPreviousRecord
            /// 知らせの中で記録した
            case answered
            /// 前の日の答えていない知らせ。文だけ
            case unansweredPastDay

            var card: NoticeCard {
                switch self {
                case .awaitingAnswer, .awaitingAnswerWithoutPreviousRecord:
                    NoticeCard(
                        notice: .sampleMissedWeightRecord(on: .sampleToday, respondedAt: nil),
                        form: .awaitingAnswer)
                case .answered:
                    NoticeCard(
                        notice: .sampleMissedWeightRecord(
                            on: .sampleToday, respondedAt: (hour: 9, minute: 30)),
                        form: .answered)
                case .unansweredPastDay:
                    NoticeCard(
                        notice: .sampleMissedWeightRecord(
                            on: CalendarDay.sampleToday.advanced(by: -1), respondedAt: nil),
                        form: .unansweredPastDay)
                }
            }

            var records: [WeightRecord] {
                switch self {
                case .awaitingAnswer, .answered, .unansweredPastDay:
                    [
                        .sample(
                            72.4, on: CalendarDay.sampleToday.advanced(by: -2), at: 7, 10,
                            from: .manual)
                    ]
                case .awaitingAnswerWithoutPreviousRecord:
                    []
                }
            }
        }
    }
#endif
