import NuToriCore
import Testing

@Suite("タイムラインの見える範囲")
struct TimelineViewportTests {
    static let yesterday = CalendarDay(year: 2026, month: 10, day: 12)
    static let today = CalendarDay(year: 2026, month: 10, day: 13)

    /// 開いて、いちばん新しい日が一番下に着き終えたところ
    static func opened(newestDay: CalendarDay = today) -> TimelineViewport {
        var viewport = TimelineViewport()
        _ = viewport.newestDayChanged(to: newestDay)
        return viewport
    }

    /// 使う人が指で動かし始めたところ
    static func touch(_ viewport: inout TimelineViewport) {
        _ = viewport.scrollPhaseChanged(from: .idle, to: .interacting)
    }

    /// 使う人が上へ動かし、一番下が画面の外に出た所で止めたところ
    static func scrolledAway(newestDay: CalendarDay = today) -> TimelineViewport {
        var viewport = opened(newestDay: newestDay)
        touch(&viewport)
        viewport.endPositionChanged(to: .offscreen)
        _ = viewport.scrollPhaseChanged(from: .interacting, to: .decelerating)
        _ = viewport.scrollPhaseChanged(from: .decelerating, to: .idle)
        return viewport
    }

    @Suite("一番下についていく")
    struct FollowingEnd {
        @Suite("開いたとき")
        struct Opening {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() {
                viewport = TimelineViewport()
                instructions = viewport.newestDayChanged(to: TimelineViewportTests.today)
            }

            @Test("開いた位置が一番下なので、動かす指示を出さないこと")
            func doesNotScroll() {
                #expect(instructions.isEmpty)
            }

            @Test("中身が伸びたら一番下についていくこと")
            func follows() {
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("いちばん新しい日が足された描画")
        struct NewestDayAdded {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened(newestDay: TimelineViewportTests.yesterday)
            }

            @Test("足された日が落ち着くまでは、ついていかないこと")
            func doesNotFollowUntilSettled() {
                #expect(!viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }

            @Test("足された日が描かれたら、一番下へ動かし、またついていくこと")
            mutating func scrollsToEndThenFollows() {
                let instructions = viewport.newestDayChanged(to: TimelineViewportTests.today)

                #expect(instructions == [.scroll(to: .end, animated: false)])
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("遡っているときに、いちばん新しい日が足されたとき")
        struct NewestDayAddedWhileScrolledAway {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway(
                    newestDay: TimelineViewportTests.yesterday)
            }

            @Test("見ている所から動かさないこと")
            mutating func staysInPlace() {
                let instructions = viewport.newestDayChanged(to: TimelineViewportTests.today)

                #expect(instructions.isEmpty)
                #expect(!viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("使う人が触っているあいだ")
        struct Interacting {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
            }

            @Test("一番下にいても、ついていかないこと")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
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

            @Test("またついていくこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
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

            @Test("一番下へ動きをつけて動かし、またついていくこと")
            func scrollsToEndAndFollows() {
                #expect(instructions == [.scroll(to: .end, animated: true)])
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("使う人が指を離して、一番下が画面の外にある所で止まったとき")
        struct ReleasedAwayFromEnd {
            let viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
            }

            @Test("ついていかないこと")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
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

            @Test("ついていき直すこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }

        @Suite("遡っているときに、返事が伸び始めたとき")
        struct GrowingReplyStarted {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
                viewport.growingReplyChanged(isGrowing: true)
            }

            @Test("ついていかないままであること")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges(newestDay: TimelineViewportTests.today))
            }
        }
    }
}
