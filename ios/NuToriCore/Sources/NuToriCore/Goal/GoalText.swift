import Foundation

/// 目標の経過（週の振り返り・目標の画面）の文に入れる、日付・量・向きの書き方
enum GoalText {
    /// 「9月14日」
    static func monthDay(_ day: CalendarDay) -> String {
        "\(day.month)月\(day.day)日"
    }

    /// 「9月14日〜20日」。月が変われば終わりにも月を書く（「9月28日〜10月4日」）
    static func dayRange(_ start: CalendarDay, _ end: CalendarDay) -> String {
        let endText = start.month == end.month ? "\(end.day)日" : monthDay(end)
        return "\(monthDay(start))〜\(endText)"
    }

    /// 「12月7日（月）」
    static func monthDayWithWeekday(_ day: CalendarDay) -> String {
        let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
        return "\(monthDay(day))（\(weekdays[day.startOfWeek.distance(to: day)])）"
    }

    /// 「減量」「増量」「維持」
    static func directionName(_ direction: Goal.Direction) -> String {
        switch direction {
        case .lose: "減量"
        case .gain: "増量"
        case .maintain: "維持"
        }
    }

    /// 「73.4 → 72.9 kg」。単位は終わりの値にだけ付ける
    static func kilogramsChange(from start: Double, to end: Double) -> String {
        // WeightAmountText.kilograms と同じく、先に 0.1 kg に丸めてから書く
        let startText = String(
            format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), (start * 10).rounded() / 10)
        return "\(startText) → \(WeightAmountText.kilograms(end))"
    }

    /// 0.1 kg 単位の値の「−0.5 kg」「+0.3 kg」「0.0 kg」。負の符号は「−」（U+2212）
    static func signedKilograms(tenths: Int) -> String {
        "\(sign(of: tenths))\(kilograms(tenths: abs(tenths)))"
    }

    /// 0.1 kg 単位の、0 以上の値の「0.4 kg」
    static func kilograms(tenths: Int) -> String {
        "\(tenths / 10).\(tenths % 10) kg"
    }

    /// kg を 0.1 kg 単位に丸める
    static func tenths(_ kilograms: Double) -> Int {
        Int((kilograms * 10).rounded())
    }

    private static func sign(of value: Int) -> String {
        value > 0 ? "+" : value < 0 ? "−" : ""
    }
}
