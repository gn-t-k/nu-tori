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
                    undelivered: .none, conversation: .none, goals: [], dailyGuides: []),
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

        /// いちばん新しい体重の時刻。今として渡すと、その体重を、たった今入力欄から足したものとみなす
        static func addedAt(_ days: [Timeline.Day]) throws -> Date {
            try #require(
                days.last?.items.last.flatMap { item -> Date? in
                    guard case .weightRecord(let record) = item else { return nil }
                    return record.instant
                })
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
            let days: [Timeline.Day]
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() throws {
                days = try ListedDays.fortyDays()
                viewport = ListedDays.opened(with: days)
                viewport.startPositionChanged(to: .atStart)
                instructions = viewport.scrollPhaseChanged(from: .idle, to: .idle, in: days)
            }

            @Test("古い日を足さず、動かす指示を出さないこと")
            func doesNotListOlderDays() {
                #expect(instructions.isEmpty)
                #expect(viewport.waitingInstructions.isEmpty)
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(3)))
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
                viewport.startPositionChanged(to: .atStart)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .decelerating, in: days)
                instructions = viewport.scrollPhaseChanged(from: .decelerating, to: .idle, in: days)
            }

            @Test("前の3日を足すこと")
            func listsOlderBatch() {
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(6)))
            }

            @Test("足した日が並ぶまで待ってから、見ていた日を上端に置き直すこと")
            func keepsPlaceAfterListing() {
                #expect(instructions.isEmpty)
                #expect(
                    viewport.waitingInstructions == [
                        .scroll(to: .day(days[37].day), animated: false)
                    ])
            }
        }

        @Suite("指で触れずに動いて（ステータスバーを押した、VoiceOver で送ったなど）、並べたいちばん古い日の上端で止まったとき")
        struct StoppedAtStartWithoutTouch {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                days = try ListedDays.fortyDays()
                viewport = ListedDays.opened(with: days)
                _ = viewport.scrollPhaseChanged(from: .idle, to: .animating, in: days)
                viewport.endPositionChanged(to: .offscreen)
                viewport.startPositionChanged(to: .atStart)
                _ = viewport.scrollPhaseChanged(from: .animating, to: .idle, in: days)
            }

            @Test("前の3日を足し、並んでから見ていた日を上端に置き直すこと")
            func listsOlderBatch() {
                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(6)))
                #expect(
                    viewport.waitingInstructions == [
                        .scroll(to: .day(days[37].day), animated: false)
                    ])
            }
        }

        @Suite("全部の日を並べているときに、上端まで遡って止めたとき")
        struct AllDaysListed {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                days = try ListedDays.days(recordCounts: [1, 0, 2])
                viewport = ListedDays.scrolledAway(from: days)
                TimelineViewportTests.touch(&viewport)
                viewport.startPositionChanged(to: .atStart)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .idle, in: days)
            }

            @Test("足す日が無いので、並べる日を変えず、動かさないこと")
            func doesNothing() {
                #expect(viewport.waitingInstructions.isEmpty)
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
                // 上端まで遡って、古い日を足す
                TimelineViewportTests.touch(&viewport)
                viewport.startPositionChanged(to: .atStart)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .idle, in: days)
                _ = viewport.takeWaitingInstructions()
                // 一番下へ戻る
                TimelineViewportTests.touch(&viewport)
                viewport.startPositionChanged(to: .belowStart)
                viewport.endPositionChanged(to: .shown)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .idle, in: days)
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

        @Suite("一番下で指で触れているときに、今日の項目が足されたとき")
        struct ItemAddedWhileTouchingAtEnd {
            let added: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                added = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [30])
                viewport = ListedDays.opened(with: days)
                TimelineViewportTests.touch(&viewport)
                _ = viewport.daysChanged(from: days, to: added, now: ListedDays.notJustAdded)
            }

            @Test("指で動かしている途中なので、並べていた3日のままにすること")
            func keepsListedDays() {
                #expect(Array(viewport.listedDays(of: added)) == Array(added.suffix(3)))
            }
        }

        @Suite("一番下で、並べていない日を選んでから動くまでのあいだに、今日の項目が足されたとき")
        struct ItemAddedBeforeLanding {
            let added: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                added = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [11])
                viewport = ListedDays.opened(with: days)
                viewport.dayChosen(days[5].day, in: days)
                _ = viewport.daysChanged(from: days, to: added, now: ListedDays.notJustAdded)
            }

            @Test("着く先の日を外さず、その日から並べたままにすること")
            func keepsLandingDay() {
                #expect(Array(viewport.listedDays(of: added)) == Array(added.suffix(35)))
            }
        }

        @Suite("並べていない日を選んで着き（止まったことは届かない）、そのあと今日の項目が足されたとき")
        struct ItemAddedAfterLanding {
            let added: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                added = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [11])
                viewport = ListedDays.opened(with: days)
                viewport.dayChosen(days[5].day, in: days)
                viewport.endPositionChanged(to: .offscreen)
                _ = viewport.daysChanged(from: days, to: added, now: ListedDays.notJustAdded)
            }

            @Test("一番下にはいないので、着いた日から並べたままにすること")
            func keepsListedDays() {
                #expect(Array(viewport.listedDays(of: added)) == Array(added.suffix(35)))
            }
        }

        @Suite("並べていない日に着いたあと、一番下へ戻ってから、今日の項目が足されたとき")
        struct ItemAddedAfterLandingAndReturningToEnd {
            let added: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                added = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [11])
                viewport = ListedDays.opened(with: days)
                viewport.dayChosen(days[5].day, in: days)
                viewport.endPositionChanged(to: .offscreen)
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .shown)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .idle, in: days)
                _ = viewport.daysChanged(from: days, to: added, now: ListedDays.notJustAdded)
            }

            @Test("着いた日を片づけ、新しいほうから項目が30個たまる3日を並べること")
            func listsNewestDaysHoldingBatch() {
                #expect(Array(viewport.listedDays(of: added)) == Array(added.suffix(3)))
            }
        }

        @Suite("遡っているときに並べていない日を選んで着き、そのあと入力欄から項目を足して一番下へ戻ったとき")
        struct ItemAddedByUserAfterLandingWhileScrolledAway {
            let afterReturning: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                let added = try ListedDays.days(
                    recordCounts: Array(repeating: 10, count: 39) + [11])
                afterReturning = try ListedDays.days(
                    recordCounts: Array(repeating: 10, count: 39) + [12])
                viewport = ListedDays.scrolledAway(from: days)
                viewport.dayChosen(days[5].day, in: days)
                _ = viewport.daysChanged(from: days, to: added, now: try ListedDays.addedAt(added))
                viewport.endPositionChanged(to: .shown)
                _ = viewport.daysChanged(
                    from: added, to: afterReturning, now: ListedDays.notJustAdded)
            }

            @Test("着いた日を片づけ、新しいほうから項目が30個たまる3日を並べること")
            func listsNewestDaysHoldingBatch() {
                #expect(
                    Array(viewport.listedDays(of: afterReturning))
                        == Array(afterReturning.suffix(3)))
            }
        }

        @Suite("一番下で、並べていない日を選んでから動くまでのあいだに、入力欄から項目を足したとき")
        struct ItemAddedByUserBeforeLanding {
            let afterAdding: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                let added = try ListedDays.days(
                    recordCounts: Array(repeating: 10, count: 39) + [11])
                afterAdding = try ListedDays.days(
                    recordCounts: Array(repeating: 10, count: 39) + [12])
                viewport = ListedDays.opened(with: days)
                viewport.dayChosen(days[5].day, in: days)
                _ = viewport.daysChanged(from: days, to: added, now: try ListedDays.addedAt(added))
                _ = viewport.daysChanged(
                    from: added, to: afterAdding, now: ListedDays.notJustAdded)
            }

            @Test("一番下へ連れていき、選んだ日を片づけ、新しいほうから項目が30個たまる3日を並べること")
            func listsNewestDaysHoldingBatch() {
                #expect(Array(viewport.listedDays(of: afterAdding)) == Array(afterAdding.suffix(3)))
            }
        }

        @Suite("一番下で、並べていない日を選んでから動くまでのあいだに、一番下へ着くよう求められたとき")
        struct EndRequestedBeforeLanding {
            let added: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let days = try ListedDays.fortyDays()
                added = try ListedDays.days(recordCounts: Array(repeating: 10, count: 39) + [11])
                viewport = ListedDays.opened(with: days)
                viewport.dayChosen(days[5].day, in: days)
                viewport.landingRequested(.end, in: days)
                _ = viewport.daysChanged(from: days, to: added, now: ListedDays.notJustAdded)
            }

            @Test("選んだ日を片づけ、新しいほうから項目が30個たまる3日を並べること")
            func listsNewestDaysHoldingBatch() {
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

            @Test("その日まで並べ、並んでからその日の区切りへ動かすこと")
            mutating func listsUpToDayThenScrolls() {
                viewport.dayChosen(days[5].day, in: days)

                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(35)))
                #expect(
                    viewport.waitingInstructions == [
                        .scroll(to: .day(days[5].day), animated: false)
                    ])
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

            @Test("その日まで並べ、並んでからそのカードへ動かすこと")
            mutating func listsUpToDayThenScrolls() {
                viewport.landingRequested(.item(item.id), in: days)

                #expect(Array(viewport.listedDays(of: days)) == Array(days.suffix(35)))
                #expect(
                    viewport.waitingInstructions == [.scroll(to: .item(item.id), animated: true)])
            }
        }

        @Suite("目標の設定を広げたカードを見せるとき")
        struct RevealingItem {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                days = try ListedDays.fortyDays()
                viewport = ListedDays.opened(with: days)
            }

            @Test("並べていない日のカードなら、その日まで並べて、まだ並んでいないと返すこと")
            mutating func listsUnlistedDay() throws {
                let item = try #require(days[5].items.first)

                let first = viewport.revealItem(item.id, in: days)
                let listed = Array(viewport.listedDays(of: days))
                let second = viewport.revealItem(item.id, in: days)

                #expect(!first)
                #expect(listed == Array(days.suffix(35)))
                #expect(second)
            }

            @Test("並べている日のカードなら、並べる日を変えずに、並んでいると返すこと")
            mutating func keepsListedDays() throws {
                let item = try #require(days.last?.items.first)
                let listed = Array(viewport.listedDays(of: days))

                let revealed = viewport.revealItem(item.id, in: days)

                #expect(revealed)
                #expect(Array(viewport.listedDays(of: days)) == listed)
            }
        }
    }
}
