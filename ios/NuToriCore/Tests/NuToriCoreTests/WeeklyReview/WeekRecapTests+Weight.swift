import Foundation
import NuToriCore
import Testing

extension WeekRecapTests {
    @Suite("体重")
    struct Weight {
        @Suite("記録が4日以上あるとき")
        struct EnoughRecords {
            let weight: WeekRecap.Weight

            init() throws {
                weight = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 20),
                        weightTrend: WeekRecapTests.trend([
                            (WeekRecapTests.day(10, 11), 71.44), (WeekRecapTests.day(10, 12), 71.4),
                            (WeekRecapTests.day(10, 16), 71.0), (WeekRecapTests.day(10, 17), 70.9),
                        ]),
                        weightRecords: try WeekRecapTests.weightRecords(on: [
                            WeekRecapTests.day(10, 12), WeekRecapTests.day(10, 14),
                            WeekRecapTests.day(10, 16), WeekRecapTests.day(10, 17),
                        ]))
                ).weight
            }

            @Test("その週の傾向の日の値で線を引くこと")
            func drawsTrendOfWeek() {
                #expect(
                    weight.trendLine
                        == .drawn([
                            WeightTrend.Day(day: WeekRecapTests.day(10, 12), kilograms: 71.4),
                            WeightTrend.Day(day: WeekRecapTests.day(10, 16), kilograms: 71.0),
                            WeightTrend.Day(day: WeekRecapTests.day(10, 17), kilograms: 70.9),
                        ]))
            }

            @Test("最初の日から最後の日への傾向を書くこと")
            func summarizesWeek() {
                #expect(weight.trendText == "傾向 71.4 → 70.9 kg")
            }
        }

        @Suite("記録が4日未満のとき")
        struct FewRecords {
            let weight: WeekRecap.Weight

            init() throws {
                weight = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 20),
                        weightTrend: WeekRecapTests.trend([
                            (WeekRecapTests.day(10, 5), 71.4), (WeekRecapTests.day(10, 14), 71.0),
                        ]),
                        weightRecords: try WeekRecapTests.weightRecords(on: [
                            WeekRecapTests.day(10, 14)
                        ]))
                ).weight
            }

            @Test("傾向の線を引かないこと")
            func skipsTrendLine() {
                #expect(weight.trendLine == .tooFewRecordedDays)
            }

            @Test("傾向が届いていても、線と組で読む傾向の値を書かないこと")
            func hasNoTrendText() {
                #expect(weight.trendText == nil)
            }
        }
    }
}
