import Foundation
import NuToriCore
import Testing

@Suite("体重のシートと知らせの中の手数")
struct WeightEntryObservationTests {
    @Suite("空欄からキーボードで開いたとき")
    struct StartsWithKeyboard {
        let observation: WeightEntryObservation

        init() {
            observation = WeightEntryObservation(
                startsWithKeyboard: true,
                openedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        @Test("入れ方がキーボードであること")
        func startsAsKeyboard() {
            #expect(observation.method == .keyboard)
            #expect(observation.stepperPressCount == 0)
        }
    }

    @Suite("前回の値からステッパーで開いたとき")
    struct StartsWithStepper {
        let openedAt: Date
        let observation: WeightEntryObservation

        init() {
            openedAt = Date(timeIntervalSince1970: 1_700_000_000)
            observation = WeightEntryObservation(startsWithKeyboard: false, openedAt: openedAt)
        }

        @Test("入れ方がステッパーで、押した回数は 0 であること")
        func startsAsStepper() {
            #expect(observation.method == .stepper)
            #expect(observation.stepperPressCount == 0)
            #expect(!observation.showedTypoHint)
        }

        @Test("ステッパーのあとキーボードにすると、入れ方がキーボードのまま回数は残ること")
        func keyboardAfterStepperKeepsTheCount() {
            var observation = observation
            observation.stepped()
            observation.stepped()
            observation.typed()

            let event = observation.recordedEvent(at: openedAt.addingTimeInterval(9))
            #expect(
                event.fields == [
                    "method": .token("keyboard"),
                    "stepper_press_count": .count(2),
                    "duration_seconds": .wholeSeconds(9),
                    "showed_typo_hint": .flag(false),
                ])
        }

        @Test("キーボードのあとステッパーにすると、入れ方がステッパーに戻ること")
        func stepperAfterKeyboard() {
            var observation = observation
            observation.typed()
            observation.stepped()

            #expect(observation.method == .stepper)
            #expect(observation.stepperPressCount == 1)
        }

        @Test("添え書きが出たことは、消えたあとも残ること")
        func keepsTheTypoHint() {
            var observation = observation
            observation.noteTypoHintShown()

            let event = observation.recordedEvent(at: openedAt.addingTimeInterval(3))
            #expect(event.fields["showed_typo_hint"] == .flag(true))
        }

        @Test("シートを開く前の時刻では、所要時間を 0 にすること")
        func clampsNegativeDuration() {
            let event = observation.recordedEvent(at: openedAt.addingTimeInterval(-5))
            #expect(event.fields["duration_seconds"] == .wholeSeconds(0))
        }
    }

    @Suite("体重の知らせのカードが見えてから記録したとき")
    struct InNotice {
        let shownAt: Date
        let observation: WeightEntryObservation

        init() {
            shownAt = Date(timeIntervalSince1970: 1_700_000_000)
            observation = .inNotice(shownAt: shownAt)
        }

        @Test("ステッパーやキーボードを使っても入れ方を notice にし、カードが見えてからの手数と所要時間を載せること")
        func recordsAsNotice() {
            var observation = observation
            observation.stepped()
            observation.typed()
            observation.stepped()

            let event = observation.recordedEvent(at: shownAt.addingTimeInterval(12))
            #expect(
                event.fields == [
                    "method": .token("notice"),
                    "stepper_press_count": .count(2),
                    "duration_seconds": .wholeSeconds(12),
                    "showed_typo_hint": .flag(false),
                ])
        }
    }
}
