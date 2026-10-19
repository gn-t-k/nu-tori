import NuToriCore
import Testing

extension WeekRecapTests {
    @Suite("週を送る")
    struct Paging {
        @Test("目標を立てた週は前の週へ送れず、そのあとの週は前の週の月曜へ送れること")
        func previousWeek() throws {
            let first = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 1), today: WeekRecapTests.day(10, 20)))
            let second = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 7), today: WeekRecapTests.day(10, 20)))

            #expect(first.previousMonday == nil)
            #expect(second.previousMonday == WeekRecapTests.day(9, 28))
        }

        @Test("今週は次の週へ送れず、その前の週は今週の月曜へ送れること")
        func nextWeek() throws {
            let lastWeek = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 20)))
            let thisWeek = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 19), today: WeekRecapTests.day(10, 20)))

            #expect(lastWeek.nextMonday == WeekRecapTests.day(10, 19))
            #expect(thisWeek.nextMonday == nil)
        }

        @Test("今日を含む週から何週前かを数えること")
        func weeksAgo() throws {
            let recaps = try [10, 12, 19].map { day in
                try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, day), today: WeekRecapTests.day(10, 20)))
            }

            #expect(recaps.map(\.weeksAgo) == [2, 1, 0])
        }
    }
}
