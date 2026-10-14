import NuToriCore

/// 期限の見出しと添え書きの日付。「12月24日」
enum GoalSetupDayText {
    static func monthDay(_ day: CalendarDay) -> String {
        "\(day.month)月\(day.day)日"
    }
}
