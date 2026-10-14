import NuToriCore
import Testing

@Suite("タイムラインの見える範囲")
struct TimelineViewportTests {
    static let yesterday = CalendarDay(year: 2026, month: 10, day: 12)
    static let today = CalendarDay(year: 2026, month: 10, day: 13)

    /// 開いて、一番下にいるところ
    static func opened() -> TimelineViewport {
        TimelineViewport()
    }

    /// 使う人が指で動かし始めたところ
    static func touch(_ viewport: inout TimelineViewport) {
        _ = viewport.scrollPhaseChanged(from: .idle, to: .interacting)
    }

    /// 使う人が上へ動かし、一番下が画面の外に出た所で止めたところ
    static func scrolledAway(from opened: TimelineViewport = opened()) -> TimelineViewport {
        var viewport = opened
        touch(&viewport)
        viewport.endPositionChanged(to: .offscreen)
        _ = viewport.scrollPhaseChanged(from: .interacting, to: .decelerating)
        _ = viewport.scrollPhaseChanged(from: .decelerating, to: .idle)
        return viewport
    }

    @Suite("一番下を追う")
    struct FollowingEnd {
        @Suite("開いたとき")
        struct Opening {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
            }

            @Test("中身が伸びたら一番下を追うこと")
            func follows() {
                #expect(viewport.followsSizeChanges)
            }
        }

        @Suite("使う人が触っているあいだ")
        struct Interacting {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
            }

            @Test("一番下にいても、追わないこと")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges)
            }
        }

        @Suite("使う人が指を離して、一番下が見えている所で止まったとき")
        struct ReleasedAtEnd {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .shown)
                instructions = viewport.scrollPhaseChanged(from: .interacting, to: .idle)
            }

            @Test("また追うこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges)
            }

            @Test("動かす指示を出さないこと")
            func doesNotScroll() {
                #expect(instructions.isEmpty)
            }
        }

        @Suite("使う人が指を離して、一番下が入力欄の下に隠れた所で止まったとき")
        struct ReleasedUnderComposer {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .underComposer)
                _ = viewport.scrollPhaseChanged(from: .interacting, to: .decelerating)
                instructions = viewport.scrollPhaseChanged(from: .decelerating, to: .idle)
            }

            @Test("一番下へ動きをつけて動かし、また追うこと")
            func scrollsToEndAndFollows() {
                #expect(instructions == [.scroll(to: .end, animated: true)])
                #expect(viewport.followsSizeChanges)
            }
        }

        @Suite("使う人が指を離して、一番下が画面の外にある所で止まったとき")
        struct ReleasedAwayFromEnd {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
            }

            @Test("追わないこと")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges)
            }
        }

        @Suite("アプリが動かして、一番下が入力欄の下に隠れた所で止まったとき")
        struct SettledByAppUnderComposer {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() {
                viewport = TimelineViewportTests.opened()
                _ = viewport.scrollPhaseChanged(from: .idle, to: .animating)
                viewport.endPositionChanged(to: .underComposer)
                instructions = viewport.scrollPhaseChanged(from: .animating, to: .idle)
            }

            @Test("着いた所に置き、動かす指示を出さないこと")
            func staysWhereItLanded() {
                #expect(instructions.isEmpty)
            }
        }

        @Suite("遡っているときに、伸びている返事が終わったとき")
        struct GrowingReplyFinished {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
                viewport.growingReplyChanged(isGrowing: false)
            }

            @Test("追わないままであること")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges)
            }

            @Test("そのあと日が変わっても、読んでいる所から動かさないこと")
            mutating func staysInPlaceWhenDayChanged() throws {
                let changed = try ListedDays.days(recordCounts: [10, 0])
                let instructions = viewport.daysChanged(
                    from: Array(changed.dropLast()), to: changed, now: ListedDays.notJustAdded)
                #expect(instructions.isEmpty)
                #expect(!viewport.followsSizeChanges)
            }
        }

        @Suite("一番下が入力欄の上に見えている所で指で触れているときに、伸びている返事が終わったとき")
        struct GrowingReplyFinishedAtEndShown {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .shown)
                viewport.growingReplyChanged(isGrowing: false)
            }

            @Test("追い直すこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges)
            }
        }

        @Suite("一番下が入力欄の下に隠れている所で指で触れているときに、伸びている返事が終わったとき")
        struct GrowingReplyFinishedAtEndUnderComposer {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .underComposer)
                viewport.growingReplyChanged(isGrowing: false)
            }

            @Test("追い直すこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges)
            }
        }

        @Suite("遡っているときに、返事が伸び始めたとき")
        struct GrowingReplyStarted {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
                viewport.growingReplyChanged(isGrowing: true)
            }

            @Test("追わないままであること")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges)
            }
        }
    }
}
