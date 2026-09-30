import NuToriCore
import Testing

@Suite("端末の利用状況の出来事")
struct ClientUsageEventTests {
    @Suite("キーボードで体重を記録したとき")
    struct WeightRecordedFromKeyboard {
        let event: ClientUsageEvent

        init() {
            event = .weightRecorded(
                method: .keyboard,
                stepperPressCount: 2,
                duration: .seconds(9),
                showedTypoHint: true
            )
        }

        @Test("値ではなく手数だけを載せること")
        func omitsTheValue() {
            #expect(event.name == "weight_recorded")
            #expect(
                event.fields == [
                    "method": .token("keyboard"),
                    "stepper_press_count": .count(2),
                    "duration_seconds": .wholeSeconds(9),
                    "showed_typo_hint": .flag(true),
                ])
        }
    }

    @Suite("上のまとまりで直したとき")
    struct CorrectedFromDaySummary {
        let event: ClientUsageEvent

        init() {
            event = .weightCorrected(.daySummary)
        }

        @Test("場所を day_summary にすること")
        func namesThePlace() {
            #expect(event.fields == ["place": .token("day_summary")])
        }
    }

    @Suite("ほかの記録で直したとき")
    struct CorrectedFromOtherRecords {
        let event: ClientUsageEvent

        init() {
            event = .weightCorrected(.otherRecords)
        }

        @Test("場所を other_records にすること")
        func namesThePlace() {
            #expect(event.fields == ["place": .token("other_records")])
        }
    }

    @Suite("最近の記録で直したとき")
    struct CorrectedFromRecentRecords {
        let event: ClientUsageEvent

        init() {
            event = .weightCorrected(.recentRecords)
        }

        @Test("場所を recent_records にすること")
        func namesThePlace() {
            #expect(event.fields == ["place": .token("recent_records")])
        }
    }
}
