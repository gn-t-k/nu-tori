import Foundation
import NuToriCore
import Testing

extension TimelineViewportTests {
    /// 1回に並べるのは、項目が 30 個たまるか 30 日になるまで
    @Suite("並べる日")
    struct ListedDays {
        /// 今日までの日の並び。`recordCounts` は古い日から今日への、日ごとの体重記録の数
        static func days(recordCounts: [Int]) throws -> [Timeline.Day] {
            let today = TimelineViewportTests.today
            let firstDay = today.advanced(by: -(recordCounts.count - 1))
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            var records: [WeightRecord] = []
            for (index, count) in recordCounts.enumerated() {
                let day = firstDay.advanced(by: index)
                for minute in 0..<count {
                    let instant = try #require(
                        calendar.date(
                            from: DateComponents(
                                year: day.year, month: day.month, day: day.day, hour: 7,
                                minute: minute)))
                    records.append(
                        WeightRecord(
                            id: UUID(), kilograms: 70, instant: instant, timeZone: .gmt,
                            inputSource: .manual, version: 1))
                }
            }
            return Timeline(
                input: Timeline.Input(
                    weightRecords: records, rejectedLines: [], meals: [], notices: [],
                    undelivered: .none, conversation: .none),
                firstDay: firstDay, today: today
            ).days
        }

        /// 毎日10個の項目がある40日。開いたときに並べるのは、新しいほうの3日
        static func fortyDays() throws -> [Timeline.Day] {
            try days(recordCounts: Array(repeating: 10, count: 40))
        }

        /// 日の並びが届いて、開いたところ
        static func opened(with days: [Timeline.Day]) -> TimelineViewport {
            var viewport = TimelineViewportTests.opened()
            _ = viewport.daysChanged(from: days, to: days, now: notJustAdded)
            return viewport
        }

        /// 使う人が上へ動かし、一番下が画面の外に出た所で止めたところ
        static func scrolledAway(from days: [Timeline.Day]) -> TimelineViewport {
            TimelineViewportTests.scrolledAway(from: opened(with: days))
        }

        /// どの記録の時刻からも離れた今。届いた項目を、たった今ここで足したものとみなさない
        static let notJustAdded = Date.distantFuture

        @Suite("項目が1回に並べる数より少ないタイムラインを開いたとき")
        struct FewItems {
            let days: [Timeline.Day]
            let viewport: TimelineViewport

            init() throws {
                days = try ListedDays.days(recordCounts: [1, 0, 2])
                viewport = ListedDays.opened(with: days)
            }

            @Test("全部の日を並べること")
            func listsAllDays() {
                #expect(Array(viewport.listedDays(of: days)) == days)
            }
        }

        @Suite("毎日10個の項目がある40日のタイムラインを開いたとき")
        struct ManyItems {
            let days: [Timeline.Day]
            let viewport: TimelineViewport

            init() throws {
                days = try ListedDays.fortyDays()
                viewport = ListedDays.opened(with: days)
            }

            @Test("新しいほうから、項目が30個たまる3日を並べること")
            func listsNewestDaysHoldingBatch() {
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(3)))
            }
        }

        @Suite("記録の無い日が40日続くタイムラインを開いたとき")
        struct EmptyDays {
            let days: [Timeline.Day]
            let viewport: TimelineViewport

            init() throws {
                days = try ListedDays.days(recordCounts: Array(repeating: 0, count: 40))
                viewport = ListedDays.opened(with: days)
            }

            @Test("新しいほうから30日を並べること")
            func listsNewestThirtyDays() {
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(30)))
            }
        }

        @Suite("開いたときに、位置が届く前の「止まっていた → 止まった」が、上端にいるように見えて届いたとき")
        struct IdleReportedAtStartOnOpening {
            let instructions: [TimelineViewport.Instruction]

            init() throws {
                var viewport = ListedDays.opened(with: try ListedDays.fortyDays())
                viewport.startReachedChanged(isAtStart: true)
                instructions = viewport.scrollPhaseChanged(from: .idle, to: .idle)
            }

            @Test("古い日を足す指示を出さないこと")
            func doesNotAskForOlderDays() {
                #expect(instructions.isEmpty)
            }
        }

        @Suite("使う人が、並べたいちばん古い日の上端まで遡って止めたとき")
        struct ReleasedAtStart {
            let days: [Timeline.Day]
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() throws {
                days = try ListedDays.fortyDays()
                viewport = ListedDays.scrolledAway(from: days)
                TimelineViewportTests.touch(&viewport)
                viewport.startReachedChanged(isAtStart: true)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .decelerating)
                instructions = viewport.scrollPhaseChanged(from: .decelerating, to: .idle)
            }

            @Test("古い日を足す指示を出すこと")
            func asksForOlderDays() {
                #expect(instructions == [.listOlderDays])
            }

            @Test("前の3日を足し、見ていた日を上端に置き直すこと")
            mutating func listsOlderBatchAndKeepsPlace() {
                let listed = viewport.listOlderDays(of: days)

                #expect(listed == [.scroll(to: .day(days[37].day), animated: false)])
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(6)))
            }
        }

        @Suite("指で触れずに動いて（ステータスバーを押した、VoiceOver で送ったなど）、並べたいちばん古い日の上端で止まったとき")
        struct StoppedAtStartWithoutTouch {
            let instructions: [TimelineViewport.Instruction]

            init() throws {
                var viewport = ListedDays.opened(with: try ListedDays.fortyDays())
                _ = viewport.scrollPhaseChanged(from: .idle, to: .animating)
                viewport.endPositionChanged(to: .offscreen)
                viewport.startReachedChanged(isAtStart: true)
                instructions = viewport.scrollPhaseChanged(from: .animating, to: .idle)
            }

            @Test("古い日を足す指示を出すこと")
            func asksForOlderDays() {
                #expect(instructions == [.listOlderDays])
            }
        }

        @Suite("全部の日を並べているとき")
        struct AllDaysListed {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                days = try ListedDays.days(recordCounts: [1, 0, 2])
                viewport = ListedDays.scrolledAway(from: days)
            }

            @Test("古い日を足そうとしても、足す日が無いので、動かさないこと")
            mutating func doesNothing() {
                #expect(viewport.listOlderDays(of: days).isEmpty)
                #expect(Array(viewport.listedDays(of: days)) == days)
            }
        }

        @Suite("今日だけのタイムラインを開いて一番下にいるときに、同期で40日ぶんの記録が届いたとき")
        struct OlderDaysArrivedAtEnd {
            let arrived: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let opened = try ListedDays.days(recordCounts: [0])
                arrived = try ListedDays.fortyDays()
                viewport = ListedDays.opened(with: opened)
                _ = viewport.daysChanged(from: opened, to: arrived, now: ListedDays.notJustAdded)
            }

            @Test("届いた並びの新しいほうから、項目が30個たまる3日を並べること")
            func listsNewestDaysHoldingBatch() {
                #expect(Array(viewport.listedDays(of: arrived)) == Array(arrived.suffix(3)))
            }
        }

        @Suite("遡って古い日を足したあと、一番下へ戻ってから、今日の項目が足されたとき")
        struct ItemAddedAfterReturningToEnd {
            let added: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                added = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [11])
                viewport = ListedDays.scrolledAway(from: days)
                _ = viewport.listOlderDays(of: days)
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .shown)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .idle)
                _ = viewport.daysChanged(from: days, to: added, now: ListedDays.notJustAdded)
            }

            @Test("足した古い日を片づけ、新しいほうから項目が30個たまる3日を並べること")
            func listsNewestDaysHoldingBatch() {
                #expect(Array(viewport.listedDays(of: added)) == Array(added.suffix(3)))
            }
        }

        @Suite("遡っているときに、並べている日の項目が減ったとき")
        struct ItemRemovedWhileScrolledAway {
            let removed: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                removed = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [5])
                viewport = ListedDays.scrolledAway(from: days)
                _ = viewport.daysChanged(from: days, to: removed, now: ListedDays.notJustAdded)
            }

            @Test("読んでいる所がずれないよう、上に日を足さず、並べていた3日のままにすること")
            func keepsListedDays() {
                #expect(Array(viewport.listedDays(of: removed)) == Array(removed.suffix(3)))
            }
        }

        @Suite("遡っているときに、今日の項目が足されたとき")
        struct ItemAddedWhileScrolledAway {
            let added: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                added = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [30])
                viewport = ListedDays.scrolledAway(from: days)
                _ = viewport.daysChanged(from: days, to: added, now: ListedDays.notJustAdded)
            }

            @Test("読んでいる日が外れないよう、並べていた3日のままにすること")
            func keepsListedDays() {
                #expect(Array(viewport.listedDays(of: added)) == Array(added.suffix(3)))
            }
        }

        @Suite("日のまとめで、並べていない日を選んだとき")
        struct UnlistedDayChosen {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                days = try ListedDays.fortyDays()
                viewport = ListedDays.opened(with: days)
            }

            @Test("その日まで並べてから、その日の区切りへ動かすこと")
            mutating func listsUpToDayThenScrolls() {
                let instructions = viewport.dayChosen(days[5].day, in: days)

                #expect(instructions == [.scroll(to: .day(days[5].day), animated: false)])
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(35)))
            }
        }

        @Suite("並べていない日のカードに着くとき")
        struct LandingOnUnlistedItem {
            let days: [Timeline.Day]
            let item: Timeline.Item
            var viewport: TimelineViewport

            init() throws {
                days = try ListedDays.fortyDays()
                item = try #require(days[5].items.first)
                viewport = ListedDays.opened(with: days)
            }

            @Test("その日まで並べてから、そのカードへ動かすこと")
            mutating func listsUpToDayThenScrolls() {
                let instructions = viewport.landingRequested(.item(item.id), in: days)

                #expect(instructions == [.scroll(to: .item(item.id), animated: true)])
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(35)))
            }
        }
    }
}
