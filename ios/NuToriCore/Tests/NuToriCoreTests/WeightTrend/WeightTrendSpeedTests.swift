import Foundation
import NuToriCore
import Testing

@Suite("日のまとめの体重の傾向の速さ")
struct WeightTrendSpeedTests {
    /// 日のまとめを開いた日
    static let day = CalendarDay(year: 2026, month: 9, day: 24)

    /// 09-17 から 09-24 までの8日、毎朝の記録
    static func eightMorningRecords() throws -> [WeightRecord] {
        try (17...24).map {
            try .manual(72.0, at: "2026-09-\($0)T07:00:00+09:00", in: "Asia/Tokyo")
        }
    }

    /// 09-17 から 09-24 までの傾向。09-17 と 09-24 だけを指定する
    static func trend(weekAgo: Double, today: Double) -> WeightTrend {
        .starting(
            CalendarDay(year: 2026, month: 9, day: 17),
            kilograms: [weekAgo, 72.0, 72.0, 72.0, 72.0, 72.0, 72.0, today])
    }

    static func speed(weekAgo: Double, today: Double) throws -> WeightTrendSpeed {
        try #require(
            WeightTrendSpeed(
                on: day, trend: trend(weekAgo: weekAgo, today: today),
                weightRecords: eightMorningRecords()))
    }

    @Suite("減っているとき")
    struct Decreasing {
        let speed: WeightTrendSpeed

        init() throws {
            speed = try WeightTrendSpeedTests.speed(weekAgo: 72.5, today: 72.26)
        }

        @Test("0.1 kg 単位に丸め、マイナスの記号をつけること")
        func roundsWithMinusSign() {
            #expect(speed.text == "1週間で −0.2 kg")
        }
    }

    @Suite("増えているとき")
    struct Increasing {
        let speed: WeightTrendSpeed

        init() throws {
            speed = try WeightTrendSpeedTests.speed(weekAgo: 72.0, today: 72.26)
        }

        @Test("0.1 kg 単位に丸め、プラスの記号をつけること")
        func roundsWithPlusSign() {
            #expect(speed.text == "1週間で +0.3 kg")
        }
    }

    @Suite("1 kg 以上減っているとき")
    struct DecreasingOverAKilogram {
        let speed: WeightTrendSpeed

        init() throws {
            speed = try WeightTrendSpeedTests.speed(weekAgo: 73.6, today: 72.38)
        }

        @Test("1の位も出すこと")
        func showsOnesDigit() {
            #expect(speed.text == "1週間で −1.2 kg")
        }
    }

    @Suite("丸めると 0 になるほど減っているとき")
    struct RoundsToZero {
        let speed: WeightTrendSpeed

        init() throws {
            speed = try WeightTrendSpeedTests.speed(weekAgo: 72.3, today: 72.26)
        }

        @Test("プラスマイナスの記号で 0 を出すこと")
        func showsZeroWithPlusMinusSign() {
            #expect(speed.text == "1週間で ±0.0 kg")
        }
    }

    @Suite("最後に測った日より後の日を開いたとき")
    struct AfterLastTrendDay {
        let speed: WeightTrendSpeed?

        init() throws {
            // 傾向は 09-23 で終わる
            speed = WeightTrendSpeed(
                on: WeightTrendSpeedTests.day,
                trend: .starting(
                    CalendarDay(year: 2026, month: 9, day: 16),
                    kilograms: Array(repeating: 72.0, count: 8)),
                weightRecords: try WeightTrendSpeedTests.eightMorningRecords())
        }

        @Test("速さを出さないこと")
        func hasNoSpeed() {
            #expect(speed == nil)
        }
    }

    @Suite("7日前に傾向が無いとき")
    struct NoTrendWeekAgo {
        let speed: WeightTrendSpeed?

        init() throws {
            // 傾向は 09-18 から
            speed = WeightTrendSpeed(
                on: WeightTrendSpeedTests.day,
                trend: .starting(
                    CalendarDay(year: 2026, month: 9, day: 18),
                    kilograms: Array(repeating: 72.0, count: 7)),
                weightRecords: try WeightTrendSpeedTests.eightMorningRecords())
        }

        @Test("速さを出さないこと")
        func hasNoSpeed() {
            #expect(speed == nil)
        }
    }

    @Suite("傾向が届いていないとき")
    struct NoTrend {
        let speed: WeightTrendSpeed?

        init() throws {
            speed = WeightTrendSpeed(
                on: WeightTrendSpeedTests.day, trend: nil,
                weightRecords: try WeightTrendSpeedTests.eightMorningRecords())
        }

        @Test("速さを出さないこと")
        func hasNoSpeed() {
            #expect(speed == nil)
        }
    }

    @Suite("その日までに記録のある日が6日で、あとの日に記録があるとき")
    struct SixRecordedDaysUntilTheDay {
        let speed: WeightTrendSpeed?

        init() throws {
            // 09-17・09-20・09-21・09-22・09-23・09-24 の6日と、あとの 09-25。傾向は欠けた日も続く
            let days = [17, 20, 21, 22, 23, 24, 25]
            speed = WeightTrendSpeed(
                on: WeightTrendSpeedTests.day,
                trend: .starting(
                    CalendarDay(year: 2026, month: 9, day: 17),
                    kilograms: Array(repeating: 72.0, count: 9)),
                weightRecords: try days.map {
                    try .manual(72.0, at: "2026-09-\($0)T07:00:00+09:00", in: "Asia/Tokyo")
                })
        }

        @Test("速さを出さないこと")
        func hasNoSpeed() {
            #expect(speed == nil)
        }
    }

    @Suite("その日までに記録のある日が7日のとき")
    struct SevenRecordedDaysUntilTheDay {
        let speed: WeightTrendSpeed?

        init() throws {
            let days = [17, 19, 20, 21, 22, 23, 24]
            speed = WeightTrendSpeed(
                on: WeightTrendSpeedTests.day,
                trend: .starting(
                    CalendarDay(year: 2026, month: 9, day: 17),
                    kilograms: Array(repeating: 72.0, count: 8)),
                weightRecords: try days.map {
                    try .manual(72.0, at: "2026-09-\($0)T07:00:00+09:00", in: "Asia/Tokyo")
                })
        }

        @Test("速さを出すこと")
        func hasSpeed() {
            #expect(speed?.text == "1週間で ±0.0 kg")
        }
    }
}
