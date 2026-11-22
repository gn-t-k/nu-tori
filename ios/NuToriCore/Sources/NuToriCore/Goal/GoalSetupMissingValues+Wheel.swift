/// 足りない値のページのホイール。並べるのは受け付ける範囲の値だけにし、範囲の外を選べないようにする
extension GoalSetupMissingValues {
    /// 身長のホイールに並べる値（cm、1 cm 刻み）
    public static let heightChoices = wholeNumbers(in: AcceptedRange.heightCentimeters.bounds)

    /// 今の体重の整数のホイールに並べる値（kg）
    public static let weightWholeChoices =
        acceptedWeightTenths.lowerBound / 10...acceptedWeightTenths.upperBound / 10

    /// 今の体重の小数のホイールに並べる値（0.1 kg の位）。範囲の端の整数では、範囲に入る位だけにする
    public static func weightTenthChoices(whole: Int) -> ClosedRange<Int> {
        max(
            0, acceptedWeightTenths.lowerBound - whole * 10)...min(
                9, acceptedWeightTenths.upperBound - whole * 10)
    }

    /// 今の体重の整数と小数の位を、0.1 kg を1とした値にまとめる。整数を範囲の端に回して小数の位が並べる値の外になったら、端に寄せる
    public static func weightTenths(whole: Int, tenth: Int) -> Int {
        let tenths = weightTenthChoices(whole: whole)
        return whole * 10 + min(max(tenth, tenths.lowerBound), tenths.upperBound)
    }

    /// kg を、0.1 kg を1とした値にする
    public static func weightTenths(kilograms: Double) -> Int {
        Int((kilograms * 10).rounded())
    }

    public static func weightKilograms(tenths: Int) -> Double {
        Double(tenths) / 10
    }

    /// 0.1 kg を1とした値の、整数のホイールの位置
    public static func weightWhole(tenths: Int) -> Int {
        tenths / 10
    }

    /// 0.1 kg を1とした値の、小数のホイールの位置
    public static func weightTenth(tenths: Int) -> Int {
        tenths % 10
    }

    /// 身長のホイールを開いたときの位置。開いただけでは入れない
    public static let initialHeightCentimeters = 170
    /// 今の体重のホイールを開いたときの位置
    public static let initialWeightKilograms = 65.0

    /// 生まれた年のホイールを開いたときの位置。1990年が選べなければ、近いほうの端
    public var initialBirthYear: Int {
        min(max(1990, selectableBirthYears.lowerBound), selectableBirthYears.upperBound)
    }

    /// 受け付ける今の体重を、0.1 kg を1とした整数で
    private static let acceptedWeightTenths = wholeNumbers(
        in: AcceptedRange.weightKilograms.bounds, scale: 10)

    private static func wholeNumbers(in bounds: AcceptedBounds, scale: Double = 1)
        -> ClosedRange<Int>
    {
        let lower = (bounds.lowerBound * scale).rounded(.up)
        let lowest = Int(bounds.contains(lower / scale) ? lower : lower + 1)
        return lowest...Int((bounds.upperBound * scale).rounded(.down))
    }
}
