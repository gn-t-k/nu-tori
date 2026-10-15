import NuToriCore
import Testing

extension TimelineViewportTests {
    /// 上の帯に隠れた高さが 100 のときで確かめる。上端にいるときのスクロールの位置は -100
    @Suite("タイムラインの上端の位置")
    struct StartPositionTests {
        static let topInset = 100.0

        @Suite("上端ちょうどにいるとき")
        struct AtStart {
            let position: TimelineViewport.StartPosition

            init() {
                position = TimelineViewport.StartPosition(
                    contentOffsetY: -StartPositionTests.topInset,
                    topInset: StartPositionTests.topInset)
            }

            @Test("上端にいること")
            func atStart() {
                #expect(position == .atStart)
            }
        }

        @Suite("上端から 1 下にいるとき")
        struct OneBelowStart {
            let position: TimelineViewport.StartPosition

            init() {
                position = TimelineViewport.StartPosition(
                    contentOffsetY: 1 - StartPositionTests.topInset,
                    topInset: StartPositionTests.topInset)
            }

            @Test("位置は小数で届くので、上端にいるとみなすこと")
            func atStart() {
                #expect(position == .atStart)
            }
        }

        @Suite("上端から 1 より下にいるとき")
        struct BelowStart {
            let position: TimelineViewport.StartPosition

            init() {
                position = TimelineViewport.StartPosition(
                    contentOffsetY: 1.5 - StartPositionTests.topInset,
                    topInset: StartPositionTests.topInset)
            }

            @Test("上端にいないこと")
            func belowStart() {
                #expect(position == .belowStart)
            }
        }
    }
}
