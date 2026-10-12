import NuToriCore
import Testing

extension TimelineViewportTests {
    @Suite("一番下へ戻す")
    struct ReturningToEnd {
        @Suite("遡っているときに、写真を撮った・選んだとき")
        struct PhotoSent {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() {
                viewport = TimelineViewportTests.scrolledAway()
                instructions = viewport.photoSent(isTimelineLoaded: true)
            }

            @Test("一番下へ動かすこと")
            func scrollsToEnd() {
                #expect(instructions == [.scroll(to: .end, animated: false)])
            }

            @Test("あとから足される食事のカードに、ついていくこと")
            func followsAddedCard() {
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("読み込み中に、写真を撮った・選んだとき")
        struct PhotoSentWhileLoading {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewport()
            }

            @Test("並んでいないので、動かす指示を出さないこと")
            mutating func doesNotScroll() {
                #expect(viewport.photoSent(isTimelineLoaded: false).isEmpty)
            }
        }

        @Suite("遡っているときに、文章を送った・送り直したとき")
        struct TextSent {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
                viewport.textSent()
            }

            @Test("ついていき直すこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("日のまとめで日を選んだとき")
        struct DayChosen {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
            }

            @Test("その日の区切りへ動かすこと")
            func scrollsToDay() {
                #expect(
                    viewport.dayChosen(TimelineViewportTests.yesterday) == [
                        .scroll(to: .day(TimelineViewportTests.yesterday), animated: false)
                    ])
            }
        }

        @Suite("知らせのカードに着くとき")
        struct LandingOnItem {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
            }

            @Test("そのカードへ、動きをつけて動かすこと")
            func scrollsToItem() {
                #expect(
                    viewport.landingRequested(.item("notice-1")) == [
                        .scroll(to: .item("notice-1"), animated: true)
                    ])
            }
        }

        @Suite("通知から、タイムラインのいちばん下に着くとき")
        struct LandingOnEnd {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
            }

            @Test("一番下へ動かすこと")
            func scrollsToEnd() {
                #expect(viewport.landingRequested(.end) == [.scroll(to: .end, animated: false)])
            }
        }
    }
}
