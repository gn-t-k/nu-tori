import Foundation
import NuToriCore
import Testing

@Suite("食事の日と時刻")
struct MealTests {
    @Suite("ロサンゼルスで撮った写真を、日本に戻ってから送ったとき")
    struct EatenAbroadSentAtHome {
        let meal: Meal

        init() throws {
            // ロサンゼルスの 9月23日 19:40 に撮り、東京の 9月25日 8:00 に送った
            meal = try .fixture(
                eatenAt: "2026-09-24T02:40:00Z", utcOffsetSeconds: -7 * 3600,
                sentAt: "2026-09-24T23:00:00Z", in: "Asia/Tokyo")
        }

        @Test("食事の日を、撮った時刻と食事の時差で決めること")
        func dayIsEatenDayInEatenOffset() {
            #expect(meal.day == CalendarDay(year: 2026, month: 9, day: 23))
        }

        @Test("カードを置く日を、送った時刻と送ったときのタイムゾーンで決めること")
        func cardDayIsSentDayInSentTimeZone() {
            #expect(meal.cardDay == CalendarDay(year: 2026, month: 9, day: 25))
        }

        @Test("時計の時刻を、撮った時刻に食事の時差を足した時刻にすること")
        func clockTimeIsInEatenOffset() {
            #expect(meal.eatenClockTime == ClockTime(hour: 19, minute: 40))
        }

        @Test("時刻を直す欄に出すタイムゾーンを、食事の時差の時計にすること")
        func eatenTimeZoneIsEatenOffset() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = meal.eatenTimeZone
            let parts = calendar.dateComponents([.day, .hour, .minute], from: meal.eatenAt)

            #expect(meal.eatenTimeZone.secondsFromGMT(for: meal.eatenAt) == -7 * 3600)
            #expect(parts.day == 23)
            #expect(parts.hour == 19)
            #expect(parts.minute == 40)
        }
    }
}
