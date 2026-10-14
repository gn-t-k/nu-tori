import NuToriCore
import Testing

@Suite("年齢")
struct AgeInYearsTests {
    @Suite("生年月日から出すとき")
    struct FromDateOfBirth {
        let dateOfBirth: CalendarDay

        init() {
            dateOfBirth = CalendarDay(year: 1990, month: 6, day: 15)
        }

        @Test("今年の誕生日の前の日は、満年齢がまだ上がらないこと")
        func dayBeforeBirthday() {
            let today = CalendarDay(year: 2026, month: 6, day: 14)
            #expect(AgeInYears.completed(since: dateOfBirth, on: today) == 35)
        }

        @Test("今年の誕生日には、満年齢が上がること")
        func onBirthday() {
            let today = CalendarDay(year: 2026, month: 6, day: 15)
            #expect(AgeInYears.completed(since: dateOfBirth, on: today) == 36)
        }
    }

    @Suite("手で入れた生まれた年から出すとき")
    struct FromBirthYear {
        @Test("今年から生まれた年を引いた数になること")
        func differenceOfYears() {
            let today = CalendarDay(year: 2026, month: 1, day: 1)
            #expect(AgeInYears.approximate(bornInYear: 1990, on: today) == 36)
        }
    }
}
