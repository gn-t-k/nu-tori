import Foundation
import NuToriCore
import Testing

@Suite("体重の傾向のグラフ")
struct WeightTrendChartTests {
    static let today = CalendarDay(year: 2026, month: 9, day: 24)

    /// 東京の朝7時の手の記録を、並べた日ごとに1つ作る
    static func morningRecords(_ days: [String]) throws -> [WeightRecord] {
        try days.map { try .manual(72.0, at: "\($0)T07:00:00+09:00", in: "Asia/Tokyo") }
    }

    static func chart(
        weightRecords: [WeightRecord],
        trend: WeightTrend?,
        firstDay: CalendarDay,
        goal: Goal? = nil
    ) -> WeightTrendChart {
        WeightTrendChart(
            weightRecords: weightRecords,
            trend: trend,
            firstDay: firstDay,
            today: today,
            goal: goal
        )
    }

    @Suite("目標体重の線")
    struct TargetWeight {
        /// 9月18日〜24日の7日、どれも 72.0 kg。縦軸は 71〜73 kg
        static func chart(goal: Goal?) throws -> WeightTrendChart {
            WeightTrendChartTests.chart(
                weightRecords: try WeightTrendChartTests.morningRecords([
                    "2026-09-18", "2026-09-19", "2026-09-20", "2026-09-21", "2026-09-22",
                    "2026-09-23", "2026-09-24",
                ]),
                trend: .starting(
                    CalendarDay(year: 2026, month: 9, day: 18),
                    kilograms: Array(repeating: 72.0, count: 7)),
                firstDay: CalendarDay(year: 2026, month: 9, day: 1),
                goal: goal)
        }

        /// `Goal.losing()` の目標体重を替えたもの
        static func losing(to kilograms: Double) throws -> Goal {
            let losing = try Goal.losing()
            return Goal(
                id: losing.id, startedDay: losing.startedDay,
                startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                targetWeightKilograms: kilograms, decidedAt: losing.decidedAt,
                timeZone: losing.timeZone, direction: losing.direction, achievement: nil,
                deadlineConfirmation: nil, closure: nil)
        }

        @Test("目標がなければ、線を引かず、縦軸は記録の幅のままであること")
        func noGoal() throws {
            let chart = try Self.chart(goal: nil)
            #expect(chart.target == nil)
            #expect(chart.kilogramsRange == 71...73)
        }

        @Test("目標体重が記録の幅に入れば、点線を引くこと")
        func lineWithinRange() throws {
            let chart = try Self.chart(goal: try Self.losing(to: 71.5))
            #expect(chart.target == .line(kilograms: 71.5))
            #expect(chart.target?.label == "目標 71.5")
            #expect(chart.kilogramsRange == 71...73)
        }

        @Test("目標体重が記録の幅より下なら、縦軸を広げず、下の端に矢印を置くこと")
        func arrowBelowRange() throws {
            let chart = try Self.chart(goal: try .losing())
            #expect(chart.target == .beyondRange(kilograms: 68.0, isAbove: false))
            #expect(chart.target?.label == "↓ 目標 68.0 kg")
            #expect(chart.kilogramsRange == 71...73)
        }

        @Test("目標体重が記録の幅より上なら、上の端に矢印を置くこと")
        func arrowAboveRange() throws {
            let chart = try Self.chart(goal: try Self.losing(to: 74.2))
            #expect(chart.target == .beyondRange(kilograms: 74.2, isAbove: true))
            #expect(chart.target?.label == "↑ 目標 74.2 kg")
        }

        @Test("維持の目標なら、保つ幅を塗り、幅が入るまで縦軸を広げること")
        func bandForMaintenance() throws {
            let chart = try Self.chart(goal: try .maintaining())
            #expect(chart.target == .band(kilograms: 65.0, halfWidthKilograms: 0.7))
            #expect(chart.target?.label == "維持 65.0 kg")
            #expect(chart.kilogramsRange == 64...73)
        }
    }

    @Suite("1日に複数の記録があるとき")
    struct SeveralRecordsInADay {
        let chart: WeightTrendChart

        init() throws {
            chart = WeightTrendChartTests.chart(
                weightRecords: [
                    try .manual(73.1, at: "2026-09-22T21:30:00+09:00", in: "Asia/Tokyo"),
                    try .imported(72.7, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo"),
                    try .manual(72.9, at: "2026-09-23T07:00:00+09:00", in: "Asia/Tokyo"),
                ],
                trend: nil,
                firstDay: CalendarDay(year: 2026, month: 9, day: 1)
            )
        }

        @Test("1日に1点、その日のいちばん早い記録の値を日の順に置くこと")
        func placesOnePointPerDay() {
            #expect(
                chart.points == [
                    .init(
                        day: CalendarDay(year: 2026, month: 9, day: 22), kilograms: 72.7,
                        isBeforeFirstDay: false),
                    .init(
                        day: CalendarDay(year: 2026, month: 9, day: 23), kilograms: 72.9,
                        isBeforeFirstDay: false),
                ])
        }
    }

    @Suite("記録のある日が7日以上で、送り待ちの記録が傾向より後の日にあるとき")
    struct PendingRecordAfterTrend {
        let chart: WeightTrendChart

        init() throws {
            // 傾向は 09-22 で終わり、09-24 の記録はまだサーバーに届いていない
            chart = WeightTrendChartTests.chart(
                weightRecords: try WeightTrendChartTests.morningRecords([
                    "2026-09-16", "2026-09-17", "2026-09-18", "2026-09-19", "2026-09-20",
                    "2026-09-21", "2026-09-22", "2026-09-24",
                ]),
                trend: .starting(
                    CalendarDay(year: 2026, month: 9, day: 16),
                    kilograms: [72.0, 72.0, 72.0, 72.0, 72.0, 72.0, 72.0]),
                firstDay: CalendarDay(year: 2026, month: 9, day: 1)
            )
        }

        @Test("送り待ちの記録の日にも点を置くこと")
        func placesPendingPoint() {
            #expect(chart.points.last?.day == CalendarDay(year: 2026, month: 9, day: 24))
        }

        @Test("線を、届いた傾向の最後の日で止めること")
        func stopsLineAtLastTrendDay() {
            guard case .drawn(let line) = chart.trendLine else {
                Issue.record("線が引かれていない: \(chart.trendLine)")
                return
            }
            #expect(line.last?.day == CalendarDay(year: 2026, month: 9, day: 22))
        }

        @Test("添え書きを出さないこと")
        func hasNoNote() {
            #expect(chart.note == nil)
        }
    }

    @Suite("使い始めた日が4週の中にあり、その前の記録もあるとき")
    struct RecordsBeforeFirstDay {
        let chart: WeightTrendChart

        init() throws {
            chart = WeightTrendChartTests.chart(
                weightRecords: try WeightTrendChartTests.morningRecords([
                    "2026-09-05", "2026-09-12",
                ]),
                trend: nil,
                firstDay: CalendarDay(year: 2026, month: 9, day: 10)
            )
        }

        @Test("使い始める前の点に印をつけること")
        func marksPointsBeforeFirstDay() {
            #expect(chart.points.map(\.isBeforeFirstDay) == [true, false])
        }

        @Test("使い始めた日に区切りを置くこと")
        func placesFirstDayDivider() {
            #expect(chart.firstDayDivider == CalendarDay(year: 2026, month: 9, day: 10))
        }
    }

    @Suite("使い始めた日が4週の左端のとき")
    struct FirstDayOnLeftEdge {
        let chart: WeightTrendChart

        init() throws {
            chart = WeightTrendChartTests.chart(
                weightRecords: [], trend: nil,
                firstDay: CalendarDay(year: 2026, month: 8, day: 28))
        }

        @Test("区切りを置くこと")
        func placesFirstDayDivider() {
            #expect(chart.firstDayDivider == CalendarDay(year: 2026, month: 8, day: 28))
        }
    }

    @Suite("使い始めた日が4週より前のとき")
    struct FirstDayBeforeWindow {
        let chart: WeightTrendChart

        init() throws {
            chart = WeightTrendChartTests.chart(
                weightRecords: [], trend: nil,
                firstDay: CalendarDay(year: 2026, month: 8, day: 27))
        }

        @Test("区切りを置かないこと")
        func hasNoFirstDayDivider() {
            #expect(chart.firstDayDivider == nil)
        }
    }

    @Suite("記録のある日が6日のとき")
    struct SixRecordedDays {
        let chart: WeightTrendChart

        init() throws {
            chart = WeightTrendChartTests.chart(
                weightRecords: try WeightTrendChartTests.morningRecords([
                    "2026-09-19", "2026-09-20", "2026-09-21", "2026-09-22", "2026-09-23",
                    "2026-09-24",
                ]),
                trend: .starting(
                    CalendarDay(year: 2026, month: 9, day: 19),
                    kilograms: [72.0, 72.0, 72.0, 72.0, 72.0, 72.0]),
                firstDay: CalendarDay(year: 2026, month: 9, day: 19)
            )
        }

        @Test("線を引かないこと")
        func drawsNoLine() {
            #expect(chart.trendLine == .tooFewRecordedDays)
        }

        @Test("線を引くまでの添え書きを出すこと")
        func showsNote() {
            #expect(chart.note == "点は測った体重。記録が増えると、傾向の線を引きます。")
        }
    }

    @Suite("記録のある日が、4週の外と使い始める前を数えて7日のとき")
    struct SevenRecordedDaysIncludingOutside {
        let chart: WeightTrendChart

        init() throws {
            // 08-20 は4週の外、09-15 は使い始める前
            chart = WeightTrendChartTests.chart(
                weightRecords: try WeightTrendChartTests.morningRecords([
                    "2026-08-20", "2026-09-15", "2026-09-20", "2026-09-21", "2026-09-22",
                    "2026-09-23", "2026-09-24",
                ]),
                trend: .starting(
                    CalendarDay(year: 2026, month: 8, day: 20),
                    kilograms: Array(repeating: 72.0, count: 36)),
                firstDay: CalendarDay(year: 2026, month: 9, day: 20)
            )
        }

        @Test("線を引くこと")
        func drawsLine() {
            guard case .drawn(let line) = chart.trendLine else {
                Issue.record("線が引かれていない: \(chart.trendLine)")
                return
            }
            #expect(!line.isEmpty)
        }
    }

    @Suite("4週の端の前後に点と傾向があるとき")
    struct WindowEdges {
        let chart: WeightTrendChart

        init() throws {
            chart = WeightTrendChartTests.chart(
                weightRecords: try WeightTrendChartTests.morningRecords([
                    "2026-08-21", "2026-08-22", "2026-08-23", "2026-08-24", "2026-08-25",
                    "2026-08-26", "2026-08-27", "2026-08-28",
                ]),
                trend: .starting(
                    CalendarDay(year: 2026, month: 8, day: 21),
                    kilograms: [72.0, 72.0, 72.0, 72.0, 72.0, 72.0, 71.9, 71.8]),
                firstDay: CalendarDay(year: 2026, month: 8, day: 1)
            )
        }

        @Test("横軸を、27 日前から今日までにすること")
        func spansFourWeeksEndingToday() {
            #expect(
                chart.days
                    == CalendarDay(
                        year: 2026, month: 8, day: 28)...CalendarDay(
                        year: 2026, month: 9, day: 24))
        }

        @Test("27 日前の点を置き、28 日前の点を置かないこと")
        func placesPointsInsideWindowOnly() {
            #expect(chart.points.map(\.day) == [CalendarDay(year: 2026, month: 8, day: 28)])
        }

        @Test("線を、27 日前からの傾向で引くこと")
        func drawsLineInsideWindowOnly() {
            #expect(
                chart.trendLine
                    == .drawn([
                        WeightTrend.Day(
                            day: CalendarDay(year: 2026, month: 8, day: 28), kilograms: 71.8)
                    ]))
        }
    }
}
