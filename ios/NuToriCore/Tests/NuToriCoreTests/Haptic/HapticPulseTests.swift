import NuToriCore
import Testing

@Suite("触覚の合図")
struct HapticPulseTests {
    @Suite("まだ何も鳴らしていないとき")
    struct NotFired {
        let pulse: HapticPulse

        init() {
            pulse = HapticPulse()
        }

        @Test("鳴らすときを持たないこと")
        func hasNoMoment() {
            #expect(pulse.moment == nil)
        }
    }

    @Suite("編集が書けたときを鳴らしたあと")
    struct Fired {
        let pulse: HapticPulse

        init() {
            var pulse = HapticPulse()
            pulse.fire(.recordWritten)
            self.pulse = pulse
        }

        @Test("鳴らしたときを持つこと")
        func hasMoment() {
            #expect(pulse.moment == .recordWritten)
        }

        @Test("同じときをもう一度鳴らすと、値が変わること")
        func changesOnSameMoment() {
            var again = pulse
            again.fire(.recordWritten)
            #expect(again != pulse)
        }
    }
}
