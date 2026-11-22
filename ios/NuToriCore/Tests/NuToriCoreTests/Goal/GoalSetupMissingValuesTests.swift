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

        @Suite("今の体重の整数が範囲の中のとき")
        struct WholeInside {
            @Test("小数は 0〜9 を並べること")
            func tenths() {
                #expect(GoalSetupMissingValues.weightTenthChoices(whole: 20) == 0...9)
                #expect(GoalSetupMissingValues.weightTenthChoices(whole: 299) == 0...9)
            }
        }

        @Suite("今の体重の整数が上の端の 300 のとき")
        struct WholeAtUpperEnd {
            @Test("小数は 0 だけを並べること")
            func tenths() {
                #expect(GoalSetupMissingValues.weightTenthChoices(whole: 300) == 0...0)
            }
        }
    }

    @Suite("今の体重の整数と小数をまとめる")
    struct WeightTenths {
        @Suite("小数が、その整数で並べる値の中にあるとき")
        struct TenthInside {
            @Test("そのままの 0.1 kg 単位の値にすること")
            func keepsTenth() {
                #expect(GoalSetupMissingValues.weightTenths(whole: 65, tenth: 3) == 653)
            }
        }

        @Suite("整数を 300 に回して、小数が並べる値の外になったとき")
        struct TenthOutside {
            @Test("小数を並べる値の端に寄せること")
            func clampsTenth() {
                #expect(GoalSetupMissingValues.weightTenths(whole: 300, tenth: 5) == 3000)
            }
        }
    }

    @Suite("生まれた年のホイールを開いたときの位置")
    struct InitialBirthYear {
        @Suite("選べる年に1990年があるとき")
        struct Inside {
            let values: GoalSetupMissingValues

            init() {
                values = GoalSetupMissingValues(
                    health: .init(heightCentimeters: nil, age: nil, sex: nil, dailySteps: [:]),
                    asksCurrentWeight: true, today: CalendarDay(year: 2026, month: 11, day: 22))
            }

            @Test("1990年にすること")
            func is1990() {
                #expect(values.initialBirthYear == 1990)
            }
        }

        @Suite("選べる年に1990年が無いとき")
        struct Outside {
            let values: GoalSetupMissingValues

            init() {
                // 年齢の上限 120 歳を超えるので、選べる年は 2001年からになる
                values = GoalSetupMissingValues(
                    health: .init(heightCentimeters: nil, age: nil, sex: nil, dailySteps: [:]),
                    asksCurrentWeight: true, today: CalendarDay(year: 2121, month: 1, day: 1))
            }

            @Test("近いほうの端にすること")
            func isNearestEnd() {
                #expect(values.initialBirthYear == values.selectableBirthYears.lowerBound)
            }
        }
    }
}
