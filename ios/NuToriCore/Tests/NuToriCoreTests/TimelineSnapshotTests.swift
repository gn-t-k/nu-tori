import Foundation
import NuToriCore
import Testing

@Suite("タイムラインの表示の値")
struct TimelineSnapshotTests {
    @Suite("初回の取得")
    struct InitialPull {
        @Suite("取りに行っている途中のとき")
        struct InProgress {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture(
                    weightRecords: [
                        try .manual(72.0, at: "2026-10-28T07:00:00+09:00", in: "Asia/Tokyo")
                    ],
                    initialPull: .inProgress)
            }

            @Test("タイムラインを組まないこと")
            func hasNoTimeline() {
                #expect(snapshot.timeline == nil)
            }

            @Test("帯には、今日の週だけを空の丸で出すこと")
            func showsEmptyWeekOfToday() {
                #expect(
                    snapshot.ringWeeks == [
                        RingStrip.Week(
                            slots: (0..<7).map { offset in
                                .ring(
                                    CalendarDay(year: 2026, month: 11, day: 2 + offset),
                                    DayRing(hasWeightRecord: false))
                            })
                    ])
            }
        }

        @Suite("取り終えて、使い始めた日がまだ決まっていないとき")
        struct StartedDayUndecided {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture(
                    weightRecords: [
                        try .manual(72.0, at: "2026-10-28T07:00:00+09:00", in: "Asia/Tokyo")
                    ],
                    initialPull: .completed(startedDay: nil))
            }

            @Test("一番古い体重記録の日からタイムラインを並べること")
            func startsFromOldestWeightRecord() throws {
                #expect(
                    try #require(snapshot.timeline).dayRange.lowerBound
                        == CalendarDay(year: 2026, month: 10, day: 28))
            }
        }
    }

    @Suite("日のまとめと体重の画面の「目標を立てる」")
    struct GoalSetupStarter {
        @Suite("目標がなく、目標を立てる知らせのカードがあるとき")
        struct NoGoalWithNotice {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture(notices: [
                    try UnansweredNoticeLineTests.goalSetup(issuedAt: "2026-10-01T09:00:00+09:00")
                ])
            }

            @Test("置くこと")
            func offers() {
                #expect(snapshot.offersGoalSetup)
            }
        }

        @Suite("目標を立てる知らせのカードがまだ無いとき")
        struct NoNotice {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture()
            }

            @Test("置かないこと")
            func doesNotOffer() {
                #expect(!snapshot.offersGoalSetup)
            }
        }

        @Suite("今の目標があるとき")
        struct WithGoal {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture(
                    notices: [
                        try UnansweredNoticeLineTests.goalSetup(
                            issuedAt: "2026-10-01T09:00:00+09:00")
                    ],
                    goals: [try Goal.losing()])
            }

            @Test("置かないこと")
            func doesNotOffer() {
                #expect(!snapshot.offersGoalSetup)
            }
        }
    }

    @Suite("無料体験とサブスクリプション")
    struct Subscription {
        @Suite("昨日で無料体験が終わったとき")
        struct FreeTrialEnded {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture(
                    subscriptionStatus: .regular(
                        freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 1)),
                        subscription: .none))
            }

            @Test("今日の先頭に、無料体験が終わった知らせを置くこと")
            func placesNoticeToday() throws {
                #expect(
                    try #require(snapshot.timeline?.days.last).items.first
                        == .subscriptionNotice(
                            SubscriptionNotice(
                                kind: .freeTrialEnded, day: TimelineSnapshot.fixtureToday)))
            }

            @Test("入力欄にサブスクリプションを求めること")
            func requiresSubscription() {
                #expect(snapshot.requiresSubscription)
            }

            @Test("開いたところを添えて、課金画面を開く求めを作ること")
            func makesPaywallRequest() {
                #expect(snapshot.paywallRequest(from: .composerChip)?.entry == .composerChip)
            }
        }

        @Suite("テストユーザーのとき")
        struct TestUser {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture(subscriptionStatus: .testUser)
            }

            @Test("課金画面を開く求めを作らないこと")
            func makesNoPaywallRequest() {
                #expect(snapshot.paywallRequest(from: .composerChip) == nil)
            }
        }

        @Suite("状態がまだ届いていないとき")
        struct NotYetSynced {
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture()
            }

            @Test("入力欄を押せるままにし、課金画面を開く求めを作らないこと")
            func neitherRequiresNorRequests() {
                #expect(!snapshot.requiresSubscription)
                #expect(snapshot.paywallRequest(from: .composerChip) == nil)
            }
        }
    }
}
