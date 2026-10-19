import Foundation

/// 週の見直しと目標の知らせの文に入れる、日付と量の書き方
enum NoticeAmountText {
    /// 「11月30日」
    static func monthDay(_ day: CalendarDay) -> String {
        "\(day.month)月\(day.day)日"
    }

    /// 「0.4 kg」
    static func kilograms(tenths: Int) -> String {
        "\(abs(tenths) / 10).\(abs(tenths) % 10) kg"
    }

    /// 「−3.6 kg」「+0.3 kg」「0.0 kg」。減る側は負の記号（U+2212）で書く
    static func signedKilograms(tenths: Int) -> String {
        "\(sign(tenths))\(kilograms(tenths: tenths))"
    }

    /// 「2,190」
    static func kilocalories(_ kilocalories: Int) -> String {
        kilocalories.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    /// 「−30 kcal」「+20 kcal」「0 kcal」
    static func signedKilocalories(_ kilocalories: Int) -> String {
        "\(sign(kilocalories))\(Self.kilocalories(abs(kilocalories))) kcal"
    }

    /// 0.1 kg 単位に四捨五入する
    static func tenths(ofKilograms kilograms: Double) -> Int {
        Int((kilograms * 10).rounded())
    }

    private static func sign(_ value: Int) -> String {
        value < 0 ? "−" : value > 0 ? "+" : ""
    }
}
