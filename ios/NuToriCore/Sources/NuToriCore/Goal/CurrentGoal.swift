/// 今の目標と、目標を立てる知らせのカードに出すその1日の目安。
/// タイムラインは、これがあれば知らせのカードを決めた目標の形にし、「目標を立てる」を置かない
public struct CurrentGoal: Hashable, Sendable {
    public let goal: Goal
    /// 当てる始まりの日が今日以前で最も遅いもの。今日より後に始まる目標なら、最も早いもの。まだ届いていなければ nil
    public let dailyGuide: DailyGuide?

    /// 今日を含む目標。無ければ（西へ移って、今日が今の目標の開始の日より前になった）閉じていない目標。どちらも無ければ nil
    /// - Parameters:
    ///   - today: 端末の今のタイムゾーンでの今日
    ///   - goals: 閉じた目標も含む
    ///   - dailyGuides: 目標がまだ届いていない1日の目安も含む
    public init?(today: CalendarDay, goals: [Goal], dailyGuides: [DailyGuide]) {
        guard
            let goal = DailyGuideForDay(on: today, goals: goals, dailyGuides: dailyGuides)?.goal
                ?? goals.first(where: { $0.closure == nil })
        else { return nil }
        self.goal = goal
        let guides = dailyGuides.filter { $0.goalId == goal.id }.sorted {
            $0.effectiveDay < $1.effectiveDay
        }
        dailyGuide = guides.last { $0.effectiveDay <= today } ?? guides.first
    }
}
