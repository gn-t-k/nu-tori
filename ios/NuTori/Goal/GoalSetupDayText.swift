import NuToriCore

/// 期限の見出しと添え書きの日付。「12月24日」
enum GoalSetupDayText {
    // DESIGN.md の日付（「9月24日（木）」）に従わず、曜日を書かない。仕様 #523 が、期限の見出しと添え書きの文を曜日の無い形（「12月24日までの目標を選んでください」）で決めているため
    static func monthDay(_ day: CalendarDay) -> String {
        "\(day.month)月\(day.day)日"
    }
}
