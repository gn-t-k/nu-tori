import Foundation
import NuToriCore
import Testing

extension TimelineViewportTests {
    @Suite("一番下へ戻す")
    struct ReturningToEnd {
        /// 「写真」で送った食事が、1つずつ、いちばん下に足されていく並び。食事は1分おきに送る
        struct MealAdditions {
            /// 0 件から `count` 件までの並び
            let days: [[Timeline.Day]]
            /// 食事を送った時刻。`days[n]` で足されたのは `sentAt[n - 1]` の食事
            let sentAt: [Date]

            init(count: Int) throws {
                let meals = try (0..<count).map { minute in
                    try MealCard.fixture(
                        eatenAt: "2026-10-13T12:\(10 + minute):00+09:00", status: nil)
                }
                days = (0...count).map { added in
                    Timeline(
                        input: Timeline.Input(
                            weightRecords: [], rejectedLines: [], meals: Array(meals.prefix(added)),
                            notices: [], undelivered: .none,
                            conversation: Timeline.Conversation(
                                sentTexts: [], statuses: [:], replies: [], streams: [:]), goals: [],
                            dailyGuides: []),
                        firstDay: TimelineViewportTests.today, today: TimelineViewportTests.today
                    ).days
                }
                sentAt = meals.map(\.meal.sentAt)
            }
        }

        @Suite("遡っているときに、ユーザーがアプリの中でいちばん下に項目を足したとき")
        struct ItemAddedByUserAtEnd {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() throws {
                let added = try MealAdditions(count: 1)
                viewport = TimelineViewportTests.scrolledAway()
                instructions = viewport.daysChanged(
                    from: added.days[0], to: added.days[1],
                    now: added.sentAt[0].addingTimeInterval(1))
            }

            @Test("日のまとめを開いていても閉じること")
            func closesDaySummary() {
                #expect(instructions == [.closeDaySummary])
            }

            @Test("足した項目が並んでから、一番下へ動かすこと")
            func scrollsToEndAfterListing() {
                #expect(viewport.waitingInstructions == [.scroll(to: .end, animated: false)])
            }

            @Test("そこから、中身が伸びたら一番下を追うこと")
            func followsFromThere() {
                #expect(viewport.followsSizeChanges)
            }
        }

        @Suite("遡っているときに、ほかの端末で足した項目が、足してから1分を過ぎていちばん下に届いたとき")
        struct ItemFromOtherDeviceArrivedAtEnd {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() throws {
                let added = try MealAdditions(count: 1)
                viewport = TimelineViewportTests.scrolledAway()
                instructions = viewport.daysChanged(
                    from: added.days[0], to: added.days[1],
                    now: added.sentAt[0].addingTimeInterval(61))
            }

            @Test("読んでいる所から動かさないこと")
            func staysInPlace() {
                #expect(instructions.isEmpty)
                #expect(viewport.waitingInstructions.isEmpty)
            }

            @Test("追わないままであること")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges)
            }
        }

        /// 送り直した吹き出しと返事は、元の時刻の位置にあり、いちばん下には足されない
        @Suite("遡っているときに、文章を送り直した・会話として送り直したとき")
        struct TextResent {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
                viewport.textResent()
            }

            @Test("追わないままであること")
            func doesNotFollow() {
                #expect(!viewport.followsSizeChanges)
            }
        }

        @Suite("一番下が入力欄の上に見えている所で指で触れているときに、文章を送り直した・会話として送り直したとき")
        struct TextResentAtEndShown {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .shown)
                viewport.textResent()
            }

            @Test("追い直すこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges)
            }
        }

        @Suite("一番下が入力欄の下に隠れている所で指で触れているときに、文章を送り直した・会話として送り直したとき")
        struct TextResentAtEndUnderComposer {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
                TimelineViewportTests.touch(&viewport)
                viewport.endPositionChanged(to: .underComposer)
                viewport.textResent()
            }

            @Test("追い直すこと")
            func followsAgain() {
                #expect(viewport.followsSizeChanges)
            }
        }

        @Suite("日のまとめで日を選んだとき")
        struct DayChosen {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
            }

            @Test("並んでから、その日の区切りへ動かすこと")
            mutating func scrollsToDay() {
                viewport.dayChosen(TimelineViewportTests.yesterday, in: [])

                #expect(
                    viewport.waitingInstructions == [
                        .scroll(to: .day(TimelineViewportTests.yesterday), animated: false)
                    ])
            }
        }

        @Suite("知らせのカードに着くとき")
        struct LandingOnItem {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.opened()
            }

            @Test("並んでから、そのカードへ、動きをつけて動かすこと")
            mutating func scrollsToItem() {
                viewport.landingRequested(.item("notice-1"), in: [])

                #expect(
                    viewport.waitingInstructions == [
                        .scroll(to: .item("notice-1"), animated: true)
                    ])
            }
        }

        @Suite("描き直して、待っている指示を受け取ったとき")
        struct WaitingInstructionsTaken {
            var viewport: TimelineViewport
            let taken: [TimelineViewport.Instruction]

            init() {
                viewport = TimelineViewportTests.scrolledAway()
                viewport.landingRequested(.end, in: [])
                taken = viewport.takeWaitingInstructions()
            }

            @Test("待っていた指示を返すこと")
            func returnsWaiting() {
                #expect(taken == [.scroll(to: .end, animated: false)])
            }

            @Test("もう待っている指示が無いこと")
            func clearsWaiting() {
                #expect(viewport.waitingInstructions.isEmpty)
            }
        }

        @Suite("通知から、タイムラインのいちばん下に着くとき")
        struct LandingOnEnd {
            var viewport: TimelineViewport

            init() {
                viewport = TimelineViewportTests.scrolledAway()
            }

            @Test("次に描いたあとで、一番下へ動かすこと")
            mutating func scrollsToEnd() {
                viewport.landingRequested(.end, in: [])

                #expect(viewport.waitingInstructions == [.scroll(to: .end, animated: false)])
            }
        }

        @Suite("記録忘れの通知を押して開き、その日の知らせが並んでいるとき")
        struct ReminderOpenedWithNotice {
            let card: Timeline.Item
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() throws {
                let notice = try Notice.missedWeightRecord(issuedAt: "2026-10-13T08:15:00+09:00")
                let timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: [notice],
                        undelivered: .none, conversation: .none, goals: [], dailyGuides: []),
                    firstDay: TimelineViewportTests.yesterday, today: TimelineViewportTests.today)
                card = .notice(NoticeCard(notice: notice, form: .awaitingAnswer))
                viewport = TimelineViewportTests.scrolledAway()
                instructions = viewport.reminderOpened(.notice(id: notice.id), in: timeline)
            }

            @Test("日のまとめを開いていても閉じること")
            func closesDaySummary() {
                #expect(instructions == [.closeDaySummary])
            }

            @Test("並んでから、その知らせのカードへ、動きをつけて動かすこと")
            func scrollsToNoticeCard() {
                #expect(
                    viewport.waitingInstructions == [.scroll(to: .item(card.id), animated: true)])
            }
        }

        @Suite("記録忘れの通知を押して開き、知らせが無いと決まったとき")
        struct ReminderOpenedWithoutNotice {
            var viewport: TimelineViewport
            let instructions: [TimelineViewport.Instruction]

            init() {
                let timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: [],
                        undelivered: .none, conversation: .none, goals: [], dailyGuides: []),
                    firstDay: TimelineViewportTests.yesterday, today: TimelineViewportTests.today)
                viewport = TimelineViewportTests.scrolledAway()
                instructions = viewport.reminderOpened(.timelineEnd, in: timeline)
            }

            @Test("日のまとめを開いていても閉じること")
            func closesDaySummary() {
                #expect(instructions == [.closeDaySummary])
            }

            @Test("次に描いたあとで、一番下へ動かすこと")
            func scrollsToEnd() {
                #expect(viewport.waitingInstructions == [.scroll(to: .end, animated: false)])
            }
        }
    }
}
