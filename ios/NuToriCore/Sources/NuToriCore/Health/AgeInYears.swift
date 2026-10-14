/// 推定消費カロリーの式に渡す年齢
public enum AgeInYears {
    /// 満年齢
    public static func completed(since dateOfBirth: CalendarDay, on today: CalendarDay) -> Int {
        let hasHadBirthdayThisYear =
            (today.month, today.day) >= (dateOfBirth.month, dateOfBirth.day)
        return today.year - dateOfBirth.year - (hasHadBirthdayThisYear ? 0 : 1)
    }

    /// 手で入れた生まれた年は月日が無いので、今年との差にする
    public static func approximate(bornInYear year: Int, on today: CalendarDay) -> Int {
        today.year - year
    }
}
