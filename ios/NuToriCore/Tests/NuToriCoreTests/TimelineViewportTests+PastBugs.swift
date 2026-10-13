import Foundation
import NuToriCore
import Testing

extension TimelineViewportTests {
    @Suite("過去の不具合の場面")
    struct PastBugs {
        @Suite("開いた直後で、日の区切りの位置が、下端へ動く前のものしか届いていないとき（#442）")
        struct StaleDayPositionsJustAfterOpening {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                // 下端へ動く前の位置。前の日が上端にあり、今日は画面の下にある
                viewport.dayPositionsChanged(
                    [
                        TimelineViewport.DayPosition(day: TimelineViewportTests.yesterday, minY: 0),
                        TimelineViewport.DayPosition(day: TimelineViewportTests.today, minY: 900),
                    ], newestDay: TimelineViewportTests.today, viewportHeight: 468)
                viewport.endPositionChanged(to: .shown)
            }

            @Test("題と1日の丸の帯が、前の日ではなく、いちばん新しい日を示すこと")
            func showsNewestDay() {
                #expect(
                    viewport.shownDay(newestDay: TimelineViewportTests.today)
                        == TimelineViewportTests.today)
            }
        }

        @Suite("文章を送ってキーボードが残っているときに、タイムラインを指で動かし始めたとき（#450）")
        struct ScrollingWithKeyboardShown {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                _ = viewport.scrollPhaseChanged(from: .idle, to: .tracking)
            }

            @Test("指がキーボードに届くのを待たずに、キーボードを下げること")
            mutating func dismissesKeyboard() {
                #expect(
                    viewport.scrollPhaseChanged(from: .tracking, to: .interacting)
                        == [.dismissKeyboard])
            }
        }

        @Suite("一番下を見ている状態で、「写真」で食事を続けて足したとき（#467）")
        struct PickingPhotosInRow {
            var viewport: TimelineViewport
            var instructions: [[TimelineViewport.Instruction]] = []

            init() throws {
                let added = try ReturningToEnd.MealAdditions(count: 5)
                viewport = TimelineViewportTests.opened()
                for index in 0..<5 {
                    instructions.append(
                        viewport.daysChanged(
                            from: added.days[index], to: added.days[index + 1],
                            now: added.sentAt[index].addingTimeInterval(1)))
                    // 動かして着く
                    _ = viewport.scrollPhaseChanged(from: .idle, to: .animating)
                    viewport.endPositionChanged(to: .shown)
                    _ = viewport.scrollPhaseChanged(from: .animating, to: .idle)
                }
            }

            @Test("毎回、いちばん新しい日の下端ではなく、下の余白まで含めた中身の下端へ動かすこと")
            func scrollsToContentEndEveryTime() {
                #expect(
                    instructions
                        == Array(repeating: [.scroll(to: .end, animated: false)], count: 5))
            }

            @Test("5枚目のあとも、足されるカードについていくこと")
            func keepsFollowing() {
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("閉じているあいだに日付が変わり、開き直して新しい日が足されたとき")
        struct ReopenedAfterDayChange {
            var viewport: TimelineViewport

            init() {
                // 前の日に、一番下を見たまま閉じた
                viewport = TimelineViewportTests.opened(newestDay: TimelineViewportTests.yesterday)
            }

            @Test("高さの見積もりの端へ動かないよう、新しい日が描かれるのを待ってから中身の下端へ動かし、そのあと今日に足される記録についていくこと")
            mutating func waitsForDayThenScrollsToEnd() {
                #expect(!viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))

                let instructions = viewport.newestDayChanged(to: TimelineViewportTests.today)

                #expect(instructions == [.scroll(to: .end, animated: false)])
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }
    }
}
