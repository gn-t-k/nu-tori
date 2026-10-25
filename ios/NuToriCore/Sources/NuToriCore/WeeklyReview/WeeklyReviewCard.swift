/// タイムラインに置く、週の振り返りのカード。見直した時刻の位置に置き、押すとその週の週の振り返りを開く。
/// 同じ時刻にまとめて見直した週は、いちばん新しい週のカード1枚にする
public struct WeeklyReviewCard: Hashable, Sendable {
    /// まとめて見直した週のうち、いちばん新しい週の見直し
    public let review: WeeklyReview
    /// 見出しの週の日付。新しい1日の目安を当てた月曜の前の月〜日で、1週目は目標の開始の日から
    public let days: ClosedRange<CalendarDay>
    /// 月〜日の小さな1日の丸。その週に当たっていた1日の目安と比べる
    public let rings: [RingStrip.Slot]
    /// 週の日曜で判定したペース。判定に要る体重の傾向がまだ届いていなければ nil で、1行を出さない
    public let pace: PaceLine?
    /// 同じ時刻にまとめて見直した、ほかの週の数
    public let otherReviewedWeekCount: Int

    public init(
        review: WeeklyReview, days: ClosedRange<CalendarDay>, rings: [RingStrip.Slot],
        pace: PaceLine?, otherReviewedWeekCount: Int
    ) {
        self.review = review
        self.days = days
        self.rings = rings
        self.pace = pace
        self.otherReviewedWeekCount = otherReviewedWeekCount
    }

    /// 見出しの週の日付。「9月14日〜20日」。月をまたぐ週は「9月28日〜10月4日」
    public var daysText: String {
        GoalText.dayRange(days.lowerBound, days.upperBound)
    }

    /// ペースの1行
    public var paceText: String? {
        pace?.text
    }

    /// 見送った週だけに出す
    public var deferralText: String? {
        switch review.outcome {
        case .deferred: "1日の目安はそのままです。"
        case .reviewed: nil
        }
    }

    /// まとめて見直したときだけに出す
    public var batchText: String? {
        otherReviewedWeekCount > 0
            ? "ほかに \(otherReviewedWeekCount) 週を見直しました。" : nil
    }

    /// カードのペースの1行。`Pace` が返さない週（期限の日か達成した日を迎えた）は、どちらを迎えたかを出す
    public enum PaceLine: Hashable, Sendable {
        case onTrack(actualTenthsOfKilogramPerWeek: Int)
        case behind(shortfallTenthsOfKilogram: Int)
        case inconclusive(weightRecordDayCount: Int)
        case pending
        case maintenance(isWithinBand: Bool)
        /// その週に達成した
        case achieved(achievedDay: CalendarDay, targetKilograms: Double)
        /// 達成した週より後の週。次の目標をまだ選んでいなければ、選べることも出す
        case reachedEarlier(canChooseNextGoal: Bool)
        case deadlinePassed(deadlineDay: CalendarDay)

        /// 週の日曜で判定する。判定に要る体重の傾向がまだ届いていなければ nil
        init?(
            goal: Goal, sunday: CalendarDay, weightTrend: WeightTrend?,
            weightRecordDays: [CalendarDay]
        ) {
            let achievedDay = goal.achievement?.achievedDay
            switch Pace(
                judgedDay: sunday, goal: goal, achievedDay: achievedDay,
                weightTrend: weightTrend, weightRecordDays: weightRecordDays)
            {
            case nil: return nil
            case .onTrack(let actual, _)?: self = .onTrack(actualTenthsOfKilogramPerWeek: actual)
            case .behind(let shortfall, _, _)?:
                self = .behind(shortfallTenthsOfKilogram: shortfall)
            case .inconclusive(let count)?: self = .inconclusive(weightRecordDayCount: count)
            case .pending?: self = .pending
            case .maintenance(let isWithinBand)?: self = .maintenance(isWithinBand: isWithinBand)
            case .unavailable?:
                if let achievedDay, achievedDay < sunday.startOfWeek {
                    self = .reachedEarlier(canChooseNextGoal: goal.closure == nil)
                } else if let achievedDay, achievedDay <= sunday {
                    self = .achieved(
                        achievedDay: achievedDay, targetKilograms: goal.targetWeightKilograms)
                } else if let deadlineDay = goal.direction.weightChange?.deadlineDay {
                    self = .deadlinePassed(deadlineDay: deadlineDay)
                } else {
                    return nil
                }
            }
        }

        public var text: String {
            switch self {
            case .onTrack(let actual):
                "間に合うペース・\(GoalText.signedKilograms(tenths: actual))／週"
            case .behind(let shortfall):
                "このままだと期限に \(GoalText.kilograms(tenths: shortfall)) 届きません"
            case .inconclusive(let count):
                "体重の記録が \(count) 日で、間に合うかはまだわかりません"
            case .pending:
                "間に合うかは、目標を立てて 14 日たつと出ます"
            case .maintenance(let isWithinBand):
                isWithinBand ? "保てています" : "保てていません"
            case .achieved(let day, let kilograms):
                "\(GoalText.monthDay(day))に \(WeightAmountText.kilograms(kilograms)) を達成しました"
            case .reachedEarlier(let canChooseNextGoal):
                canChooseNextGoal ? "目標に届いています・次の目標を選べます" : "目標に届いています"
            case .deadlinePassed(let day):
                "\(GoalText.monthDay(day))が期限でした"
            }
        }
    }
}
