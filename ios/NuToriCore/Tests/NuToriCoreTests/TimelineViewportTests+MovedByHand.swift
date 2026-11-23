import NuToriCore
import Testing

extension TimelineViewportTests {
    @Suite("指で動かしているか")
    struct MovedByHand {
        @Suite("開いたとき")
        struct Opened {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
            }

            @Test("指で動かしていないこと")
            func isNotMovedByHand() {
                #expect(!viewport.isMovedByHand)
            }
        }

        @Suite("使う人が触っているあいだ")
        struct Interacting {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
            }

            @Test("指で動かしていること")
            func isMovedByHand() {
                #expect(viewport.isMovedByHand)
            }
        }

        @Suite("指を離して惰性で動いているあいだ")
        struct Decelerating {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .decelerating, in: [])
            }

            @Test("指で動かしていること")
            func isMovedByHand() {
                #expect(viewport.isMovedByHand)
            }
        }

        @Suite("使う人が動かして止まったとき")
        struct Stopped {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
            }

            @Test("指で動かしていないこと")
            func isNotMovedByHand() {
                #expect(!viewport.isMovedByHand)
            }
        }

        @Suite("アプリが動きをつけて動かしているあいだ")
        struct Animating {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                _ = viewport.scrollPhaseChanged(from: .idle, to: .animating, in: [])
            }

            @Test("指で動かしていないこと")
            func isNotMovedByHand() {
                #expect(!viewport.isMovedByHand)
            }
        }
    }
}
