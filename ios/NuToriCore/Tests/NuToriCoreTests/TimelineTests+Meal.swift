import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("食事のカードの置き場")
    struct PlacingMeals {
        static let day = CalendarDay(year: 2026, month: 9, day: 24)

        @Suite("前の日に撮った写真の食事を送ったとき")
        struct PhotoFromPreviousDay {
            let meal: MealCard
            let timeline: Timeline

            init() throws {
                meal = MealCard(
                    meal: try .fixture(
                        eatenAt: "2026-09-23T19:40:00+09:00", sentAt: "2026-09-24T08:00:00+09:00"),
                    status: .estimated, recordedOnThisDevice: true)
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [meal]),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: PlacingMeals.day
                )
            }

            @Test("撮った日でなく、送った日にカードを置くこと")
            func placesOnSentDay() {
                #expect(timeline.days.map(\.items) == [[], [.meal(meal)]])
            }
        }

        @Suite("今日より先の日に送った食事があるとき")
        struct MealAfterToday {
            let timeline: Timeline

            init() throws {
                let meal = MealCard(
                    meal: try .fixture(
                        eatenAt: "2026-09-25T12:10:00+09:00", sentAt: "2026-09-25T12:11:00+09:00"),
                    status: nil, recordedOnThisDevice: true)
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [meal]),
                    firstDay: PlacingMeals.day,
                    today: PlacingMeals.day
                )
            }

            @Test("カードのある先の日まで並べること")
            func listsUpToDayOfCard() {
                #expect(timeline.dayRange.upperBound == CalendarDay(year: 2026, month: 9, day: 25))
            }
        }

        @Suite("体重記録と食事が同じ日にあるとき")
        struct WithWeightRecords {
            let morning: WeightRecord
            let evening: WeightRecord
            let lunch: MealCard
            let timeline: Timeline

            init() throws {
                morning = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                evening = try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
                // 撮ったのは朝の体重より前だが、送ったのは昼
                lunch = MealCard(
                    meal: try .fixture(
                        eatenAt: "2026-09-24T06:00:00+09:00", sentAt: "2026-09-24T12:11:00+09:00"),
                    status: .estimating, recordedOnThisDevice: true)
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [evening, morning], rejectedLines: [], meals: [lunch]),
                    firstDay: PlacingMeals.day,
                    today: PlacingMeals.day
                )
            }

            @Test("体重記録の時刻と、食事の送った時刻の順に並べること")
            func sortsBySentAt() {
                #expect(
                    timeline.days.first?.items == [
                        .weightRecord(morning), .meal(lunch), .weightRecord(evening),
                    ])
            }
        }

        @Suite("写真を選んで、同じ送った時刻の食事が3つできたとき")
        struct SameSentAt {
            let breakfast: MealCard
            let lunch: MealCard
            let dinner: MealCard
            let timeline: Timeline

            init() throws {
                let sentAt = "2026-09-24T22:00:00+09:00"
                breakfast = MealCard(
                    meal: try .fixture(eatenAt: "2026-09-24T07:30:00+09:00", sentAt: sentAt),
                    status: nil, recordedOnThisDevice: true)
                lunch = MealCard(
                    meal: try .fixture(eatenAt: "2026-09-24T12:10:00+09:00", sentAt: sentAt),
                    status: nil, recordedOnThisDevice: true)
                dinner = MealCard(
                    meal: try .fixture(eatenAt: "2026-09-24T19:40:00+09:00", sentAt: sentAt),
                    status: nil, recordedOnThisDevice: true)
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [dinner, breakfast, lunch]),
                    firstDay: PlacingMeals.day,
                    today: PlacingMeals.day
                )
            }

            @Test("撮った時刻の順に並べること")
            func sortsByEatenAt() {
                #expect(
                    timeline.days.first?.items == [
                        .meal(breakfast), .meal(lunch), .meal(dinner),
                    ])
            }
        }

        @Suite("サーバーが受け付けなかった食事があるとき")
        struct RejectedMeal {
            let before: MealCard
            let line: RejectedMealLine
            let morning: WeightRecord
            let timeline: Timeline

            init() throws {
                morning = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                before = MealCard(
                    meal: try .fixture(
                        eatenAt: "2026-09-24T07:30:00+09:00", sentAt: "2026-09-24T07:31:00+09:00"),
                    status: .estimated, recordedOnThisDevice: true)
                line = RejectedMealLine(
                    meal: try .fixture(
                        eatenAt: "2026-09-24T06:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00"))
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [morning], rejectedLines: [.meal(line)], meals: [before]),
                    firstDay: PlacingMeals.day,
                    today: PlacingMeals.day
                )
            }

            @Test("カードを置いていた位置（送った時刻）に行を置くこと")
            func placesLineAtSentAt() {
                #expect(
                    timeline.days.first?.items == [
                        .weightRecord(morning), .meal(before), .rejectedMealLine(line),
                    ])
            }
        }

        @Suite("サーバーに記録の無い体重の行と、食事が同じ日にあるとき")
        struct RejectedWeightBetweenMeals {
            let lunch: MealCard
            let line: RejectedWeightLine
            let timeline: Timeline

            init() throws {
                lunch = MealCard(
                    meal: try .fixture(
                        eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00"),
                    status: .estimated, recordedOnThisDevice: true)
                line = RejectedWeightLine(
                    record: try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                    serverHasValue: false)
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [.weight(line)], meals: [lunch]),
                    firstDay: PlacingMeals.day,
                    today: PlacingMeals.day
                )
            }

            @Test("体重の行を、あとに送った食事より前に置くこと")
            func placesWeightLineBeforeLaterMeal() {
                #expect(
                    timeline.days.first?.items == [.rejectedWeightLine(line), .meal(lunch)])
            }
        }
    }
}
