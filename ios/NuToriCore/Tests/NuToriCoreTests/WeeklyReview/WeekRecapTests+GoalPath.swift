import NuToriCore
import Testing

extension WeekRecapTests {
    @Suite("体重の段の目標の道筋")
    struct GoalPath {
        @Test("減量は、開始の日の傾向から期限の日の目標体重へ引いた線の、並べた最初と最後の日の値にすること")
        func losing() throws {
            // 10月1日から12月24日までの 84 日で 72.4 kg から 68.0 kg へ。10月12日は 11 日目、18日は 17 日目
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 20)))

            let path = recap.weight.goalPath
            #expect(abs(path.firstKilograms - 71.8238) < 0.0001)
            #expect(abs(path.lastKilograms - 71.5095) < 0.0001)
        }

        @Test("維持は、目標体重の横の線にすること")
        func maintaining() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 26), today: WeekRecapTests.day(11, 5),
                    goals: [.maintaining()]))

            #expect(recap.weight.goalPath == .init(firstKilograms: 65.0, lastKilograms: 65.0))
        }
    }
}
