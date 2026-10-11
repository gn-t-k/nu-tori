import NuToriCore
import Testing

/// iPhone 18 Pro で記録した値（#469）で確かめる。入力欄より上に見えている高さが 468、入力欄に隠れた高さが 220
@Suite("タイムラインの下端の位置")
struct TimelineEndPositionTests {
    static let shownHeight = 468.0
    static let hiddenByComposer = 220.0
    static let contentHeight = 1303.0

    /// スクロールの位置が offset のときの位置
    static func position(offset: Double, contentHeight: Double = contentHeight)
        -> TimelineEndPosition
    {
        TimelineEndPosition(
            visibleMaxY: offset + shownHeight + hiddenByComposer,
            hiddenByComposer: hiddenByComposer, contentHeight: contentHeight)
    }

    @Suite("下端ちょうどにいるとき")
    struct AtEnd {
        let position: TimelineEndPosition

        init() {
            position = TimelineEndPositionTests.position(
                offset: TimelineEndPositionTests.contentHeight
                    - TimelineEndPositionTests.shownHeight)
        }

        @Test("入力欄の上に見えていること")
        func shown() {
            #expect(position == .shown)
        }

        @Test("止まったときに、また追うこと")
        func follows() {
            #expect(position.followsWhenSettled)
        }
    }

    @Suite("中身が画面より短いとき")
    struct ShortContent {
        let position: TimelineEndPosition

        init() {
            position = TimelineEndPositionTests.position(
                offset: 0, contentHeight: TimelineEndPositionTests.shownHeight)
        }

        @Test("入力欄の上に見えていること")
        func shown() {
            #expect(position == .shown)
        }
    }

    @Suite("下端から入力欄の高さより少なく上にいるとき")
    struct NearEnd {
        let position: TimelineEndPosition

        init() {
            // 下端ちょうど（835）より 100 上
            position = TimelineEndPositionTests.position(offset: 735)
        }

        @Test("入力欄の下に隠れていること")
        func underComposer() {
            #expect(position == .underComposer)
        }

        @Test("止まったときに、また追うこと")
        func follows() {
            #expect(position.followsWhenSettled)
        }
    }

    @Suite("下端から入力欄の高さより上にいるとき")
    struct AwayFromEnd {
        let position: TimelineEndPosition

        init() {
            // 下端ちょうど（835）より 335 上
            position = TimelineEndPositionTests.position(offset: 500)
        }

        @Test("画面の外にあること")
        func offscreen() {
            #expect(position == .offscreen)
        }

        @Test("止まっても追わないこと")
        func doesNotFollow() {
            #expect(!position.followsWhenSettled)
        }
    }
}
