import Charts
import NuToriCore
import SwiftUI

/// 月〜日の曜日の目盛り
enum WeekdayAxis {
    static func marks(monday: CalendarDay) -> some AxisContent {
        AxisMarks(values: Array(0...6)) { value in
            AxisValueLabel(centered: false) {
                if let offset = value.as(Int.self) {
                    Text(TimelineDayText.weekdaySymbol(for: monday.advanced(by: offset)))
                        .font(.caption2)
                }
            }
        }
    }
}
