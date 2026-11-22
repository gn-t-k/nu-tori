import NuToriCore
import Testing

@Suite("押した操作の触覚の合図")
struct HapticPulseTests {
    @Suite("まだ何も押していないとき")
    struct NotFired {
        let pulse: HapticPulse

        init() {
            pulse = HapticPulse()
        }

        @Test("押した操作を持たないこと")
        func hasNoMoment() {
            #expect(pulse.moment == nil)
        }
    }

    @Suite("「写真を使用」を押したあと")
    struct Fired {
        let pulse: HapticPulse

        init() {
            var pulse = HapticPulse()
            pulse.fire(.photoUsed)
            self.pulse = pulse
        }

        @Test("押した操作を持つこと")
        func hasMoment() {
            #expect(pulse.moment == .photoUsed)
        }

        @Test("同じ操作をもう一度押すと、値が変わること")
        func changesOnSameMoment() {
            var again = pulse
            again.fire(.photoUsed)
            #expect(again != pulse)
        }
    }
}
