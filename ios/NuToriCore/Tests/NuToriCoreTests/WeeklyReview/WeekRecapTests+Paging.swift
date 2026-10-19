import NuToriCore
import Testing

extension WeekRecapTests {
    @Suite("週を送る")
    struct Paging {
        @Suite("目標を立てた週と、その次の週")
        struct FirstAndSecondWeek {
            let first: WeekRecap
            let second: WeekRecap

            init() throws {
                first = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 1), today: WeekRecapTests.day(10, 20)))
                second = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 7), today: WeekRecapTests.day(10, 20)))
            }

            @Test("目標を立てた週は前の週へ送れず、そのあとの週は前の週の月曜へ送れること")
            func previousWeek() {
                #expect(first.previousMonday == nil)
                #expect(second.previousMonday == WeekRecapTests.day(9, 28))
            }
        }

        @Suite("先週と今週")
        struct LastAndThisWeek {
            let lastWeek: WeekRecap
            let thisWeek: WeekRecap

            init() throws {
                lastWeek = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 20)))
                thisWeek = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 19), today: WeekRecapTests.day(10, 20)))
            }

            @Test("今週は次の週へ送れず、その前の週は今週の月曜へ送れること")
            func nextWeek() {
                #expect(lastWeek.nextMonday == WeekRecapTests.day(10, 19))
                #expect(thisWeek.nextMonday == nil)
            }
        }

        @Suite("2週前から今週まで")
        struct ThreeWeeks {
            let recaps: [WeekRecap]

            init() throws {
                recaps = try [10, 12, 19].map { day in
                    try #require(
                        try WeekRecapTests.recap(
                            weekOf: WeekRecapTests.day(10, day), today: WeekRecapTests.day(10, 20)))
                }
            }

            @Test("今日を含む週から何週前かを数えること")
            func weeksAgo() {
                #expect(recaps.map(\.weeksAgo) == [2, 1, 0])
            }
        }
    }
}
