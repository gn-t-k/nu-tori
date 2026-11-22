import NuToriCore
import Testing

@Suite("足りない値のページのホイール")
struct GoalSetupMissingValuesTests {
    @Suite("並べる値")
    struct Choices {
        @Test("身長は受け付ける範囲の 100〜250 cm を並べること")
        func heights() {
            #expect(GoalSetupMissingValues.heightChoices == 100...250)
        }

        @Test("今の体重の整数は受け付ける範囲の 20〜300 を並べること")
        func weightWholes() {
            #expect(GoalSetupMissingValues.weightWholeChoices == 20...300)
        }

        @Test("今の体重の小数は、範囲の中の整数では 0〜9 を並べること")
        func weightTenthsInside() {
            #expect(GoalSetupMissingValues.weightTenthChoices(whole: 20) == 0...9)
            #expect(GoalSetupMissingValues.weightTenthChoices(whole: 299) == 0...9)
        }

        @Test("今の体重の小数は、上の端の 300 では 0 だけを並べること")
        func weightTenthsAtUpperEnd() {
            #expect(GoalSetupMissingValues.weightTenthChoices(whole: 300) == 0...0)
        }
    }

    @Suite("開いたときの位置")
    struct InitialPositions {
        @Test("身長は 170 cm、今の体重は 65.0 kg にすること")
        func heightAndWeight() {
            #expect(GoalSetupMissingValues.initialHeightCentimeters == 170)
            #expect(GoalSetupMissingValues.initialWeightKilograms == 65.0)
        }

        @Test("生まれた年は、選べる年にあれば 1990年にすること")
        func birthYearInside() {
            let values = GoalSetupMissingValues(
                health: Self.noHealth, asksCurrentWeight: true,
                today: CalendarDay(year: 2026, month: 11, day: 22))

            #expect(values.initialBirthYear == 1990)
        }

        @Test("生まれた年は、選べる年に1990年が無ければ、近いほうの端にすること")
        func birthYearClamped() {
            // 年齢の上限 120 歳を超えるので、選べる年は 2001年からになる
            let values = GoalSetupMissingValues(
                health: Self.noHealth, asksCurrentWeight: true,
                today: CalendarDay(year: 2121, month: 1, day: 1))

            #expect(values.initialBirthYear == values.selectableBirthYears.lowerBound)
        }

        private static let noHealth = HealthBodyData(
            heightCentimeters: nil, age: nil, sex: nil, dailySteps: [:])
    }
}
