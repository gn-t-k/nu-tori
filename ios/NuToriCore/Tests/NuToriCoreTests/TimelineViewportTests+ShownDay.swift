import NuToriCore
import Testing

extension TimelineViewportTests {
    /// 見えている高さは 468（iPhone 18 Pro の、入力欄より上）
    @Suite("題と1日の丸の帯に出す日")
    struct ShownDay {
        static let viewportHeight = 468.0
        static let twoDaysAgo = CalendarDay(year: 2026, month: 10, day: 11)

        /// 一番下が画面の外にあり、日の区切りの上端が positions にあるところ
        static func scrolledAway(
            to positions: [TimelineViewport.DayPosition]
        ) -> TimelineViewport {
            var viewport = TimelineViewportTests.scrolledAway()
            viewport.dayPositionsChanged(
                positions, newestDay: TimelineViewportTests.today, viewportHeight: viewportHeight)
            return viewport
        }

        @Suite("一番下が見えているとき")
        struct EndShown {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                // 前の日が長く、上端にかかっている
                viewport.dayPositionsChanged(
                    [
                        TimelineViewport.DayPosition(
                            day: TimelineViewportTests.yesterday, minY: -300),
                        TimelineViewport.DayPosition(day: TimelineViewportTests.today, minY: 500),
                    ], newestDay: TimelineViewportTests.today,
                    viewportHeight: ShownDay.viewportHeight)
            }

            @Test("いちばん新しい日であること")
            func newestDay() {
                #expect(
                    viewport.shownDay(newestDay: TimelineViewportTests.today)
                        == TimelineViewportTests.today)
            }
        }

        @Suite("遡っていて、いちばん新しい日の区切りの上端が画面に入っているとき")
        struct NewestDayInView {
            let viewport: TimelineViewport

            init() {
                viewport = ShownDay.scrolledAway(to: [
                    TimelineViewport.DayPosition(day: TimelineViewportTests.yesterday, minY: -300),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.today, minY: 467),
                ])
            }

            @Test("いちばん新しい日であること")
            func newestDay() {
                #expect(
                    viewport.shownDay(newestDay: TimelineViewportTests.today)
                        == TimelineViewportTests.today)
            }
        }

        @Suite("遡っていて、いちばん新しい日の区切りの上端が画面の下に出たとき")
        struct NewestDayBelowView {
            let viewport: TimelineViewport

            init() {
                viewport = ShownDay.scrolledAway(to: [
                    TimelineViewport.DayPosition(day: ShownDay.twoDaysAgo, minY: -900),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.yesterday, minY: 8),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.today, minY: 468),
                ])
            }

            @Test("上端にかかっている日のうち、いちばん下の日であること")
            func dayAtTop() {
                #expect(
                    viewport.shownDay(newestDay: TimelineViewportTests.today)
                        == TimelineViewportTests.yesterday)
            }
        }

        @Suite("遡っていて、次の日の区切りがまだ上端に届いていないとき")
        struct NextDayNotYetAtTop {
            let viewport: TimelineViewport

            init() {
                viewport = ShownDay.scrolledAway(to: [
                    TimelineViewport.DayPosition(day: ShownDay.twoDaysAgo, minY: -900),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.yesterday, minY: 9),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.today, minY: 700),
                ])
            }

            @Test("上端にかかっている前の日であること")
            func previousDay() {
                #expect(
                    viewport.shownDay(newestDay: TimelineViewportTests.today)
                        == ShownDay.twoDaysAgo)
            }
        }

        @Suite("遡っていて、いちばん新しい日の区切りの上端が少しだけ上にはみ出しているとき")
        struct NewestDaySlightlyAbove {
            let viewport: TimelineViewport

            init() {
                viewport = ShownDay.scrolledAway(to: [
                    TimelineViewport.DayPosition(day: TimelineViewportTests.yesterday, minY: -500),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.today, minY: -39),
                ])
            }

            @Test("いちばん新しい日であること")
            func newestDay() {
                #expect(
                    viewport.shownDay(newestDay: TimelineViewportTests.today)
                        == TimelineViewportTests.today)
            }
        }

        @Suite("どの日の区切りも上端より下にあるとき")
        struct NoDayAtTop {
            let viewport: TimelineViewport

            init() {
                viewport = ShownDay.scrolledAway(to: [
                    TimelineViewport.DayPosition(day: ShownDay.twoDaysAgo, minY: 40),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.yesterday, minY: 300),
                    TimelineViewport.DayPosition(day: TimelineViewportTests.today, minY: 900),
                ])
            }

            @Test("いちばん上にある日であること")
            func topmostDay() {
                #expect(
                    viewport.shownDay(newestDay: TimelineViewportTests.today)
                        == ShownDay.twoDaysAgo)
            }
        }
    }
}
