extension WeekRecap {
    /// 体重の段。記録の点は日ごとの `Day.weightKilograms`、目標の道筋の点線は目標から描く
    public struct Weight: Hashable, Sendable {
        public let trendLine: TrendLine
        /// 並べた最初の日以前で最も新しい体重の傾向。まだ無ければ nil
        public let firstTrendKilograms: Double?
        /// 並べた最後の日以前で最も新しい体重の傾向。まだ無ければ nil
        public let lastTrendKilograms: Double?
        /// 体重記録のある日の数
        public let recordedDayCount: Int
        /// 並べた日の数
        public let dayCount: Int

        init(shownDays: ClosedRange<CalendarDay>, days: [Day], records: GoalRecords) {
            recordedDayCount = days.count { $0.weightKilograms != nil }
            dayCount = days.count
            trendLine =
                recordedDayCount < Self.minimumRecordedDays
                ? .tooFewRecordedDays
                : .drawn(records.weightTrend?.days.filter { shownDays.contains($0.day) } ?? [])
            firstTrendKilograms = records.trendKilograms(onOrBefore: shownDays.lowerBound)
            lastTrendKilograms = records.trendKilograms(onOrBefore: shownDays.upperBound)
        }

        /// 「傾向 73.4 → 72.9 kg」。傾向がまだ無ければ nil
        public var trendText: String? {
            guard let firstTrendKilograms, let lastTrendKilograms else { return nil }
            return
                "傾向 \(GoalText.kilogramsChange(from: firstTrendKilograms, to: lastTrendKilograms))"
        }

        /// 「記録 6 日（7日中）」
        public var recordText: String {
            "記録 \(recordedDayCount) 日（\(dayCount)日中）"
        }

        /// 傾向の線を引かないときに添える文
        public var note: String? {
            switch trendLine {
            case .drawn: nil
            case .tooFewRecordedDays: "傾向の線は、記録がたまると引きます"
            }
        }

        public enum TrendLine: Hashable, Sendable {
            /// その週の、届いた傾向の日の値
            case drawn([WeightTrend.Day])
            /// 記録のある日が4日未満で、あてにならない線を見せないために引かない
            case tooFewRecordedDays
        }

        private static let minimumRecordedDays = 4
    }
}
