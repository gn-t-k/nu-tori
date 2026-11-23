import NuToriCore
import Testing

extension TimelineViewportTests {
    @Suite("指で動かしているか")
    struct MovedByHand {
        @Test("開いたときは、指で動かしていないこと")
        func opened() {
            #expect(!TimelineViewportTests.opened().isMovedByHand)
        }

        @Test("指で動かし始めたら、指で動かしていること")
        func touched() {
            var viewport = TimelineViewportTests.opened()
            TimelineViewportTests.touch(&viewport)
            #expect(viewport.isMovedByHand)
        }

        @Test("指を離して惰性で動いているあいだも、指で動かしていること")
        func decelerating() {
            var viewport = TimelineViewportTests.opened()
            TimelineViewportTests.touch(&viewport)
            _ = viewport.scrollPhaseChanged(from: .interacting, to: .decelerating, in: [])
            #expect(viewport.isMovedByHand)
        }

        @Test("止まったら、指で動かしていないこと")
        func stopped() {
            #expect(!TimelineViewportTests.scrolledAway().isMovedByHand)
        }

        @Test("アプリが動きをつけて動かしているあいだは、指で動かしていないこと")
        func animating() {
            var viewport = TimelineViewportTests.opened()
            _ = viewport.scrollPhaseChanged(from: .idle, to: .animating, in: [])
            #expect(!viewport.isMovedByHand)
        }
    }
}
