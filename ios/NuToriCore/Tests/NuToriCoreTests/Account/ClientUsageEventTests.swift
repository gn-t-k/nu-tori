import NuToriCore
import Testing

@Suite("端末の利用状況の出来事")
struct ClientUsageEventTests {
    @Test("体重を記録した出来事に、値ではなく手数だけを載せること")
    func weightRecordedOmitsTheValue() {
        let event = ClientUsageEvent.weightRecorded(
            method: .keyboard,
            stepperPressCount: 2,
            duration: .seconds(9),
            showedTypoHint: true
        )

        #expect(event.name == "weight_recorded")
        #expect(
            event.fields == [
                "method": .token("keyboard"),
                "stepper_press_count": .count(2),
                "duration_seconds": .wholeSeconds(9),
                "showed_typo_hint": .flag(true),
            ])
    }

    @Test("体重を直した場所を、上のまとまり・ほかの記録・最近の記録で分けること")
    func weightCorrectedNamesThePlace() {
        #expect(
            ClientUsageEvent.weightCorrected(.daySummary).fields == [
                "place": .token("day_summary")
            ])
        #expect(
            ClientUsageEvent.weightCorrected(.otherRecords).fields == [
                "place": .token("other_records")
            ])
        #expect(
            ClientUsageEvent.weightCorrected(.recentRecords).fields == [
                "place": .token("recent_records")
            ])
    }
}
