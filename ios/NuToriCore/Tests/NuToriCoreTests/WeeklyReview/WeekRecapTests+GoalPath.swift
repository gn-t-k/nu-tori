import NuToriCore
import Testing

extension WeekRecapTests {
    @Suite("体重の段の目標の道筋")
    struct GoalPath {
        @Suite("減量の目標のとき")
        struct Losing {
            let path: WeekRecap.Weight.GoalPath

            init() throws {
                // 10月1日から12月24日までの 84 日で 72.4 kg から 68.0 kg へ。10月12日は 11 日目、18日は 17 日目
                path = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 20))
                ).weight.goalPath
            }

            @Test("開始の日の傾向から期限の日の目標体重へ引いた線の、並べた最初と最後の日の値にすること")
            func followsLineToDeadline() {
                #expect(abs(path.firstKilograms - 71.8238) < 0.0001)
                #expect(abs(path.lastKilograms - 71.5095) < 0.0001)
            }
        }

        @Suite("維持の目標のとき")
        struct Maintaining {
            let path: WeekRecap.Weight.GoalPath

            init() throws {
                path = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 26), today: WeekRecapTests.day(11, 5),
                        goals: [.maintaining()])
                ).weight.goalPath
            }

            @Test("目標体重の横の線にすること")
            func staysAtTarget() {
                #expect(path == .init(firstKilograms: 65.0, lastKilograms: 65.0))
            }
        }
    }
}
