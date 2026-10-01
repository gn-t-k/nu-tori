import Foundation

public enum WeightAmountText {
    public static func kilograms(_ kilograms: Double) -> String {
        let rounded = (kilograms * 10).rounded() / 10
        return String(format: "%.1f kg", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }

    public static func clock(_ time: ClockTime) -> String {
        let minute = String(format: "%02d", locale: Locale(identifier: "en_US_POSIX"), time.minute)
        return "\(time.hour):\(minute)"
    }
}
