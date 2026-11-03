import Foundation
import NuToriCore
import Testing

extension TimelineViewportTests {
    /// 今日でなく項目も無い日は、見出しを描かず、画面に区切りを置かない（`Timeline.Day.showsHeading`）
    @Suite("見出しを描かない日")
    struct EmptyDays {
        @Suite("日のまとめで、見出しを描かない日を選んだとき")
        struct EmptyDayChosen {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                // 2日目と3日目が空、今日（最後）は項目が無くても見出しを描く
                days = try ListedDays.days(recordCounts: [1, 0, 0, 2, 0])
                viewport = ListedDays.opened(with: days)
            }

            @Test("その次の、見出しを描く日の区切りへ動かすこと")
            mutating func landsOnNextDayWithHeading() {
                viewport.dayChosen(days[1].day, in: days)

                #expect(
                    viewport.waitingInstructions == [
                        .scroll(to: .day(days[3].day), animated: false)
                    ]
                )
            }
        }

        @Suite("日のまとめで、後ろに見出しを描く日が無い、見出しを描かない日を選んだとき")
        struct EmptyDayChosenWithoutLaterHeading {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                let withRecord = try ListedDays.days(recordCounts: [1])
                let empty = Timeline.Day(
                    day: TimelineViewportTests.today.advanced(by: 1), isToday: false, items: [],
                    food: DayFood(meals: []), dailyGuide: nil)
                days = withRecord + [empty]
                viewport = ListedDays.opened(with: days)
            }

            @Test("一番下へ動かすこと")
            mutating func landsOnEnd() {
                viewport.dayChosen(days[1].day, in: days)

                #expect(viewport.waitingInstructions == [.scroll(to: .end, animated: false)])
            }
        }

        @Suite("見出しを描かない日をはさむタイムラインを開いたとき")
        struct DrawnDaysAroundEmptyDays {
            let days: [Timeline.Day]
            let viewport: TimelineViewport

            init() throws {
                // 2日目と3日目が空、今日（最後）は項目が無くても見出しを描く
                days = try ListedDays.days(recordCounts: [1, 0, 0, 2, 0])
                viewport = ListedDays.opened(with: days)
            }

            @Test("見出しを描かない日を外して描くこと")
            func drawsDaysWithHeadingOnly() {
                #expect(viewport.drawnDays(of: days) == [days[0], days[3], days[4]])
            }
        }

        @Suite("見出しを描かない日が、1回に並べる分より長く続く記録を、上端まで遡って止めたとき")
        struct ManyEmptyDaysBeforeListed {
            let days: [Timeline.Day]
            var viewport: TimelineViewport

            init() throws {
                // 古い5日に10個ずつ、そのあと40日空いて、3日に10個ずつ、今日は空
                days = try ListedDays.days(
                    recordCounts: Array(repeating: 10, count: 5) + Array(repeating: 0, count: 40)
                        + Array(repeating: 10, count: 3) + [0])
                viewport = ListedDays.scrolledAway(from: days)
                TimelineViewportTests.touch(&viewport)
                viewport.startPositionChanged(to: .atStart)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .idle, in: days)
            }

            @Test("空の日を越えて、見出しを描く古い日を足すこと")
            func listsOlderDaysWithHeading() {
                let listed = viewport.listedDays(of: days)
                #expect(listed.first?.day == days[2].day)
                #expect(listed.first?.showsHeading == true)
            }

            @Test("足した日が並んでから、見ていた日（見出しを描くいちばん古い日）を上端に置き直すこと")
            func keepsPlaceOnDayWithHeading() {
                #expect(
                    viewport.waitingInstructions == [
                        .scroll(to: .day(days[45].day), animated: false)
                    ])
            }
        }

        @Suite("開いたときに並べる分が、見出しを描かない日をはさんで続くとき")
        struct EmptyDaysInsideOpeningBatch {
            let days: [Timeline.Day]
            let viewport: TimelineViewport

            init() throws {
                // 古い2日に10個ずつ、そのあと40日空いて、2日に10個ずつ、今日は空
                days = try ListedDays.days(
                    recordCounts: [10, 10] + Array(repeating: 0, count: 40) + [10, 10, 0])
                viewport = ListedDays.opened(with: days)
            }

            @Test("空の日を数えずに越え、項目が30個たまる日から並べること")
            func listsAcrossEmptyDays() {
                #expect(viewport.listedDays(of: days).first?.day == days[1].day)
            }
        }
    }
}
