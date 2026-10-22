#if DEBUG
    import Foundation
    import NuToriCore
    import Synchronization
    import Testing

    @testable import NuTori

    @Suite("UI テストの時計")
    struct DeviceClockFrozenTests {
        @Suite("1秒あけて文章を2つ送ったとき")
        struct TwoSentTexts {
            let day: CalendarDay
            let input: Timeline.Input

            init() throws {
                let elapsed = Elapsed()
                let timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
                let clock = try frozenClock(elapsed: elapsed, timeZone: timeZone)
                // 前に送った文章の ID が、あとに送った文章の ID より後ろに来る組にする。
                // 時刻が同じなら ID の順で並び、あとに送ったものが上に来る（#586）
                let first = try sentText(
                    id: "FFFFFFFF-0000-0000-0000-000000000000", body: "前", clock: clock,
                    timeZone: timeZone)
                elapsed.seconds = 1
                let second = try sentText(
                    id: "00000000-0000-0000-0000-000000000000", body: "あと", clock: clock,
                    timeZone: timeZone)
                day = clock.today()
                input = Timeline.Input(
                    goalRecords: GoalRecords(
                        goals: [], dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                        weightTrend: nil, weightRecords: []), rejectedLines: [], meals: [],
                    notices: [], undelivered: .none,
                    conversation: Timeline.Conversation(
                        sentTexts: [second, first], statuses: [:], replies: [], streams: [:]),
                    subscriptionNotices: [])
            }

            @Test("サーバーがミリ秒に丸めても、送った順に並ぶこと")
            func keepsSentOrder() {
                let timeline = Timeline(input: input, firstDay: day, today: day)

                let bodies = timeline.days.flatMap(\.items).compactMap { item -> String? in
                    if case .sentText(let bubble) = item { bubble.sentText.body } else { nil }
                }
                #expect(bodies == ["前", "あと"])
            }
        }

        @Suite("起動から10分たったとき")
        struct TenMinutesLater {
            let clock: DeviceClock
            let timeZone: TimeZone

            init() throws {
                let elapsed = Elapsed()
                timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
                clock = try frozenClock(elapsed: elapsed, timeZone: timeZone)
                elapsed.seconds = 600
            }

            @Test("分は起動の値のまま変わらないこと")
            func staysInLaunchMinute() {
                let minute = Calendar(identifier: .gregorian).dateComponents(
                    in: timeZone, from: clock.now())
                #expect([minute.hour, minute.minute] == [6, 30])
            }
        }

        private static func frozenClock(elapsed: Elapsed, timeZone: TimeZone) throws -> DeviceClock
        {
            let clock = DeviceClock.frozen(
                atLaunchValue: "2026-10-05T06:30", in: timeZone, elapsed: { elapsed.seconds })
            return try #require(clock)
        }

        /// サーバーは送った時刻をミリ秒で持つので、取り直した文章と同じく、ミリ秒に切り捨てる
        private static func sentText(
            id: String, body: String, clock: DeviceClock, timeZone: TimeZone
        ) throws -> SentText {
            let milliseconds = (clock.now().timeIntervalSince1970 * 1000).rounded(.down)
            return SentText(
                id: try #require(UUID(uuidString: id)), body: body,
                sentAt: Date(timeIntervalSince1970: milliseconds / 1000), timeZone: timeZone)
        }

        /// 起動してからの経過を、テストが進める
        final class Elapsed: Sendable {
            private let value = Mutex<TimeInterval>(0)

            var seconds: TimeInterval {
                get { value.withLock { $0 } }
                set { value.withLock { $0 = newValue } }
            }
        }
    }
#endif
