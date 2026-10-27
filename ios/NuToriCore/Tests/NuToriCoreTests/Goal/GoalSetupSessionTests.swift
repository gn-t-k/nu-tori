import Foundation
import NuToriAPI
import NuToriCore
import Testing

@MainActor
@Suite("目標の設定の流れを持つもの")
struct GoalSetupSessionTests {
    /// 維持を選ぶと目標案が出て、決められる流れを、開くたびに作る
    static func session(madeFlows: Tally) -> GoalSetupSession {
        GoalSetupSession(
            today: { CalendarDay(year: 2026, month: 1, day: 1) },
            start: { _ in
                .first(
                    firstUseDay: CalendarDay(year: 2025, month: 12, day: 20),
                    hasWeightRecords: true)
            },
            makeFlow: { start in
                madeFlows.add()
                return GoalSetupFlowHarness(
                    start: start,
                    answers: [
                        "preview": [
                            .json(
                                GoalSetupJSON.preview(
                                    canBackCalculate: true, canOfferLoseProposals: nil))
                        ],
                        "proposals": [.json(GoalSetupJSON.maintenance())],
                        "decisions": [.json(GoalSetupJSON.decided)],
                    ]
                ).flow
            })
    }

    @MainActor
    @Suite("向きを選んでから閉じたとき")
    struct ClosedHalfway {
        let madeFlows: Tally
        let session: GoalSetupSession

        init() async throws {
            madeFlows = Tally()
            session = GoalSetupSessionTests.session(madeFlows: madeFlows)
            await session.open(from: .noticeCard, on: .timeline)
            let flow = try #require(session.flow)
            await flow.chooseDirection(.maintain)
            flow.close()
        }

        @Test("開き直すと、同じ流れを同じページから広げること")
        func reopensSameFlow() async {
            await session.open(from: .daySummary, on: .goalScreen)

            #expect(madeFlows.count == 1)
            #expect(session.flow?.isOpen == true)
            #expect(session.flow?.page == .maintenance)
            #expect(session.place == .goalScreen)
        }

        @Test("捨てると、流れが無くなること")
        func discardsFlow() {
            session.discard()

            #expect(session.flow == nil)
        }
    }

    @MainActor
    @Suite("目標を決めたあと")
    struct Decided {
        let madeFlows: Tally
        let session: GoalSetupSession

        init() async throws {
            madeFlows = Tally()
            session = GoalSetupSessionTests.session(madeFlows: madeFlows)
            await session.open(from: .noticeCard, on: .timeline)
            let flow = try #require(session.flow)
            await flow.chooseDirection(.maintain)
            await flow.decide()
            try #require(flow.decision == .decided)
            flow.close()
        }

        @Test("開き直すと、新しい流れを作って最初のページから広げること")
        func startsNewFlow() async {
            await session.open(from: .setNextGoal, on: .timeline)

            #expect(madeFlows.count == 2)
            #expect(session.flow?.isOpen == true)
            #expect(session.flow?.direction == nil)
        }
    }
}
