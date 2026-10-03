import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("日ごとの食べた量")
    struct FoodOfDay {
        static let nutrients: [Nutrient: Double] = [
            .energyKcal: 520, .proteinG: 10, .fatG: 10, .carbohydrateG: 17.5,
        ]

        @Suite("前の日に撮った写真の食事を、次の日に送ったとき")
        struct PhotoFromPreviousDay {
            let timeline: Timeline

            init() throws {
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [],
                        meals: [
                            try .fixture(
                                eatenAt: "2026-09-23T19:40:00+09:00",
                                sentAt: "2026-09-24T08:00:00+09:00", status: .estimated,
                                nutrients: FoodOfDay.nutrients)
                        ], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("カードは送った日に置き、食べた量は撮った日に入れること")
            func countsOnEatenDay() throws {
                #expect(timeline.days.map(\.items.count) == [0, 1])
                #expect(timeline.days[0].food.figures?.totals[.energyKcal] == .exactly(520))
                #expect(timeline.days[1].food == .noMeals)
            }

            @Test("丸は撮った日だけ塗ること")
            func paintsRingOfEatenDay() {
                #expect(timeline.days.map(\.ring.hasRecordedFood) == [true, false])
            }
        }

        @Suite("使い始めた日より前に撮った写真の食事を、使い始めた日に送ったとき")
        struct PhotoFromBeforeFirstDay {
            let timeline: Timeline

            init() throws {
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [],
                        meals: [
                            try .fixture(
                                eatenAt: "2026-09-22T19:40:00+09:00",
                                sentAt: "2026-09-23T08:00:00+09:00", status: .estimated,
                                nutrients: FoodOfDay.nutrients)
                        ], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 23)
                )
            }

            @Test("カードは並べても、日の食べた量にも丸にも入れないこと")
            func isLeftOutOfFood() {
                #expect(timeline.days.map(\.items.count) == [1])
                #expect(timeline.days.map(\.food) == [.noMeals])
                #expect(timeline.days.map(\.ring.hasRecordedFood) == [false])
            }
        }

        @Suite("同じ日に、推定が済んだ食事と推定中の食事があるとき")
        struct FinishedAndEstimating {
            let timeline: Timeline

            init() throws {
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [],
                        meals: [
                            try .fixture(
                                eatenAt: "2026-09-24T08:00:00+09:00", status: .estimated,
                                nutrients: FoodOfDay.nutrients),
                            try .fixture(eatenAt: "2026-09-24T12:00:00+09:00", status: .estimating),
                        ], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("済んだ食事の分を出し、済んでいない食事の数を持つこと")
            func hasPendingCount() throws {
                let figures = try #require(timeline.days.first?.food.figures)

                #expect(figures.totals[.energyKcal] == .exactly(520))
                #expect(figures.pendingMealCount == 1)
            }
        }

        @Suite("体重記録のある日")
        struct WithWeightRecord {
            @Test("体重の印と食べた量の丸を、それぞれ持つこと")
            func keepsWeightAndFood() throws {
                let timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [
                            try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                        ], rejectedLines: [],
                        meals: [
                            try .fixture(
                                eatenAt: "2026-09-24T08:00:00+09:00", status: .estimated,
                                nutrients: FoodOfDay.nutrients)
                        ], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )

                let ring = try #require(timeline.days.first?.ring)

                #expect(ring.hasWeightRecord)
                #expect(ring.hasRecordedFood)
            }
        }
    }
}
