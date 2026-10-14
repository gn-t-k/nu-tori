/// その日を含む目標と、その目標の1日の目安のうち、その日に当たるもの。1日の丸と日のまとめが、その日の食べた量を比べる先。
/// 電波が無くても丸を見せるため、キャッシュの目標と1日の目安の記録で引く。
/// サーバーにも同じ手順を置く（`docs/agents/shared-rules.md` の「その日の1日の目安」。サーバーは `findDailyGuideForDay`）
public struct DailyGuideForDay: Hashable, Sendable {
    public let goal: Goal
    /// その目標の1日の目安がまだ届いていなければ nil。そのときも、その日は比べない
    public let dailyGuide: DailyGuide?

    /// その日を含む目標が無ければ nil（目標を立てる前の日。その日は比べない）
    /// - Parameters:
    ///   - goals: 閉じた目標も含む
    ///   - dailyGuides: 目標がまだ届いていない1日の目安も含む
    public init?(on day: CalendarDay, goals: [Goal], dailyGuides: [DailyGuide]) {
        // 同じ日に2回立て直すと、間の目標は開始の日と終わった日が同じになり、どの日も含まない
        let containing = goals.filter { goal in
            goal.startedDay <= day && (goal.closure.map { $0.endedDay > day } ?? true)
        }
        guard
            let goal = containing.max(by: { lhs, rhs in
                (lhs.startedDay, lhs.decidedAt) < (rhs.startedDay, rhs.decidedAt)
            })
        else {
            return nil
        }
        self.goal = goal
        // 2つ目以降の目標の1日の目安は、当てる始まりの日がその日以前でいくら遅くても選ばない
        dailyGuide =
            dailyGuides
            .filter { $0.goalId == goal.id && $0.effectiveDay <= day }
            .max { $0.effectiveDay < $1.effectiveDay }
    }
}
