import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Synchronization

/// 目標の設定の流れと、その差し替え一式。今は日本時間の 2026-01-01 09:00（期限の初期値は 2026-04-01）
@MainActor
struct GoalSetupFlowHarness {
    let flow: GoalSetupFlow
    let server: GoalSetupServerStub
    let records: GoalSetupRecordsMock
    let health: HealthStoreMock
    let clock: SteppingClock
    let observations: ObservationLog

    init(
        start: GoalSetupStart = .first(
            firstUseDay: CalendarDay(year: 2025, month: 12, day: 20), hasWeightRecords: true),
        answers: [String: [GoalSetupServerStub.Answer]],
        health: HealthStoreMock = .ok(),
        records: GoalSetupRecordsMock = .ok()
    ) {
        let server = GoalSetupServerStub(answers)
        let clock = SteppingClock()
        let observations = ObservationLog()
        self.server = server
        self.records = records
        self.health = health
        self.clock = clock
        self.observations = observations
        flow = GoalSetupFlow(
            start: start,
            client: NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: server.transport,
                appBuildGate: .sample,
                sessionToken: { "session-1" }),
            records: records,
            health: .fixture(healthStore: health),
            timeZone: { GoalSetupHealthReader.fixtureTimeZone },
            now: { Date(timeIntervalSince1970: 1_767_225_600) },
            wait: clock.wait,
            errorReporting: ErrorReportingSessionMock.ok(),
            observe: { observations.append($0) })
    }

    /// 送った本文を JSON の辞書で読む
    func sentBodies(_ endpoint: String) throws -> [[String: Any]] {
        try server.bodies(endpoint).map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] ?? [:]
        }
    }

    final class ObservationLog: Sendable {
        var all: [GoalSetupObservation] {
            state.withLock { $0 }
        }

        func append(_ observation: GoalSetupObservation) {
            state.withLock { $0.append(observation) }
        }

        private let state = Mutex<[GoalSetupObservation]>([])
    }
}

/// 目標の設定の要求の答えの JSON
enum GoalSetupJSON {
    static func preview(canBackCalculate: Bool?, canOfferLoseProposals: Bool?) -> String {
        var fields: [String] = []
        if let canBackCalculate { fields.append(#""canBackCalculate":\#(canBackCalculate)"#) }
        if let canOfferLoseProposals {
            fields.append(#""canOfferLoseProposals":\#(canOfferLoseProposals)"#)
        }
        return "{\(fields.joined(separator: ","))}"
    }

    /// 減量の目標案。`offered` に無い速さは出せない枠。kcal は案の1日の目安
    static func loseProposals(
        startedOn: String = "2026-01-01",
        lastWeightRecordedOn: String = "2025-12-31",
        offered: [String: (targetWeightKg: Double, energyKcal: Int)] = [
            "gentle": (68.5, 2050), "standard": (66.5, 1850), "hard": (64.5, 1650),
        ]
    ) -> String {
        let proposals = ["gentle", "standard", "hard"].map { pace in
            guard let value = offered[pace] else {
                return
                    #"{"pace":"\#(pace)","status":"unavailable","unavailableReason":"daily_guide_below_minimum"}"#
            }
            return """
                {"pace":"\(pace)","status":"offered","targetWeightKg":\(value.targetWeightKg),
                "dailyGuide":\(dailyGuide(value.energyKcal)),"difficulty":"\(pace)",
                "dailyGuideDifferenceKcal":\(value.energyKcal - 2250)}
                """
        }
        let range =
            offered.isEmpty
            ? ""
            : #","acceptedTargetWeightRange":{"minimumKg":64.0,"maximumKg":69.9,"fastestEndReason":"pace_too_fast"}"#
        return """
            {"startedOn":"\(startedOn)","direction":"lose","expenditureKcal":2250,
            "expenditureSource":"back_calculated","startingWeightTrendKg":70.0,
            "lastWeightRecordedOn":"\(lastWeightRecordedOn)","deadlineOn":"2026-04-01",
            "proposals":[\(proposals.joined(separator: ","))]\(range)}
            """
    }

    static func maintenance(energyKcal: Int = 2250) -> String {
        """
        {"startedOn":"2026-01-01","direction":"maintain","expenditureKcal":2250,
        "expenditureSource":"formula","startingWeightTrendKg":65.0,"lastWeightRecordedOn":"2025-12-31",
        "maintenance":{"targetWeightKg":65.0,"dailyGuide":\(dailyGuide(energyKcal))}}
        """
    }

    static func acceptedCustom(energyKcal: Int) -> String {
        """
        {"startedOn":"2026-01-01","status":"accepted","dailyGuide":\(dailyGuide(energyKcal)),
        "difficulty":"standard","dailyGuideDifferenceKcal":\(energyKcal - 2250)}
        """
    }

    static let goalId = "00000000-0000-4000-8000-0000000000c1"

    static let decided = """
        {"status":"decided","changes":[{"kind":"goal","recordId":"\(goalId)","record":{
        "id":"\(goalId)","startedOn":"2026-01-01","startingWeightTrendKg":70.0,
        "targetWeightKg":66.5,"decidedAt":1767225600000,"timeZone":"Asia/Tokyo",
        "direction":"lose","weightChange":{"deadlineOn":"2026-04-01","pacePlan":"standard"}}}]}
        """

    static func recalculated(_ proposals: String) -> String {
        #"{"status":"recalculated","proposals":"# + proposals + "}"
    }

    static func dailyGuide(_ energyKcal: Int) -> String {
        #"{"energyKcal":\#(energyKcal),"proteinG":105,"fatG":50,"carbohydrateG":240}"#
    }
}
