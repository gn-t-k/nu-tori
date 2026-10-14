/// 目標の設定を始めるときの、その人の状況。初めてか立て直しかで、出すページと要求に載せるものが変わる
public enum GoalSetupStart: Sendable, Equatable {
    /// 初めて目標を立てる。`firstUseDay` は使い始めた日（使い始める前の摂取エネルギーを読む窓の終わり）
    case first(firstUseDay: CalendarDay, hasWeightRecords: Bool)
    /// 今の目標を閉じて立て直す。ヘルスケアの許可と足りない値のページを出さない
    case restart(currentGoalStartedDay: CalendarDay)

    /// キャッシュの記録から決める。閉じていない目標があれば立て直し。使い始めた日がまだ無ければ今日
    public init(
        goals: [Goal], hasWeightRecords: Bool, startedOn: String?, today: CalendarDay
    ) {
        if let current = goals.first(where: { $0.closure == nil }) {
            self = .restart(currentGoalStartedDay: current.startedDay)
        } else {
            self = .first(
                firstUseDay: startedOn.flatMap(CalendarDay.init(yearMonthDay:)) ?? today,
                hasWeightRecords: hasWeightRecords)
        }
    }

    var isFirst: Bool {
        switch self {
        case .first: true
        case .restart: false
        }
    }

    /// 開始の日。今日が今の目標の開始の日より前なら（西へ移ったあと）、今の目標の開始の日（サーバーと同じ決まり）
    func startDay(today: CalendarDay) -> CalendarDay {
        switch self {
        case .first: today
        case .restart(let currentGoalStartedDay): max(today, currentGoalStartedDay)
        }
    }
}
