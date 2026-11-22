import NuToriCore
import Testing

@Suite("触覚を鳴らすときごとの型")
struct HapticTrialTests {
    @Suite("選び直していないとき")
    struct Standard {
        let trial: HapticTrial

        init() {
            trial = .standard
        }

        @Test("どのときも本番の型を返すこと")
        func returnsStandard() {
            #expect(HapticMoment.allCases.allSatisfy { trial[$0] == $0.standard })
        }
    }

    @Suite("推定できなかったときを error に選び直したとき")
    struct Chosen {
        var trial: HapticTrial

        init() {
            trial = .standard
            trial[.mealEstimationFailed] = .error
        }

        @Test("選び直した型を返すこと")
        func returnsChosen() {
            #expect(trial[.mealEstimationFailed] == .error)
        }

        @Test("ほかのときは本番の型のままにすること")
        func keepsOthers() {
            #expect(trial[.mealEstimated] == .success)
        }

        @Test("本番の型に選び直すと、選び直していないものと等しくなること")
        mutating func equalsStandardAfterChoosingStandard() {
            trial[.mealEstimationFailed] = .silent
            #expect(trial == .standard)
        }
    }
}
