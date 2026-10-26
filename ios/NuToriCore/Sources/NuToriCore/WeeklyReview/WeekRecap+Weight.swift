extension WeekRecap {
    /// 体重の段。記録の点は日ごとの `Day.weightKilograms`、目標の道筋の点線は目標から描く
    public struct Weight: Hashable, Sendable {
        public let trendLine: TrendLine
        /// 目標の道筋の点線の、並べた最初の日と最後の日の値
        public let goalPath: GoalPath
        /// 並べた最初の日以前で最も新しい体重の傾向。まだ無ければ nil
        public let firstTrendKilograms: Double?
        /// 並べた最後の日以前で最も新しい体重の傾向。まだ無ければ nil
        public let lastTrendKilograms: Double?
        /// 体重記録のある日の数
        public let recordedDayCount: Int
        /// 並べた日の数
        public let dayCount: Int

        init(
            goal: Goal, shownDays: ClosedRange<CalendarDay>, days: [Day], records: GoalRecords
        ) {
            goalPath = GoalPath(goal: goal, shownDays: shownDays)
            recordedDayCount = days.count { $0.weightKilograms != nil }
            dayCount = days.count
            trendLine =
                recordedDayCount < Self.minimumRecordedDays
                ? .tooFewRecordedDays
                : .drawn(records.weightTrend?.days.filter { shownDays.contains($0.day) } ?? [])
            firstTrendKilograms = records.trendKilograms(onOrBefore: shownDays.lowerBound)
            lastTrendKilograms = records.trendKilograms(onOrBefore: shownDays.upperBound)
        }

        /// 「傾向 73.4 → 72.9 kg」。傾向がまだ無いか、傾向の線を引かない週は nil（線と組で読む値なので）
        public var trendText: String? {
            guard case .drawn = trendLine, let firstTrendKilograms, let lastTrendKilograms else {
                return nil
            }
            return
                "傾向 \(GoalText.kilogramsChange(from: firstTrendKilograms, to: lastTrendKilograms))"
        }

        /// 「記録 6 日（7日中）」
        public var recordText: String {
            "記録 \(recordedDayCount) 日（\(dayCount)日中）"
        }

        /// 目標の道筋。減量・増量は開始の日の体重の傾向から期限の日の目標体重への直線、維持は目標体重の横の線
        public struct GoalPath: Hashable, Sendable {
            public let firstKilograms: Double
            public let lastKilograms: Double

            public init(firstKilograms: Double, lastKilograms: Double) {
                self.firstKilograms = firstKilograms
                self.lastKilograms = lastKilograms
            }

            init(goal: Goal, shownDays: ClosedRange<CalendarDay>) {
                func kilograms(on day: CalendarDay) -> Double {
                    guard let deadline = goal.direction.weightChange?.deadlineDay else {
                        return goal.targetWeightKilograms
                    }
                    let total = goal.startedDay.distance(to: deadline)
                    guard total > 0 else { return goal.targetWeightKilograms }
                    // 期限を過ぎた日は目標体重のまま
                    let elapsed = min(max(goal.startedDay.distance(to: day), 0), total)
                    return goal.startingWeightTrendKilograms
                        + (goal.targetWeightKilograms - goal.startingWeightTrendKilograms)
                        * Double(elapsed) / Double(total)
                }
                firstKilograms = kilograms(on: shownDays.lowerBound)
                lastKilograms = kilograms(on: shownDays.upperBound)
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
