import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("ユーザーがアプリの中でいちばん下に足したか")
    struct ItemByUserAtEnd {
        static let yesterday = CalendarDay(year: 2026, month: 9, day: 23)
        static let today = CalendarDay(year: 2026, month: 9, day: 24)

        static func morning() throws -> WeightRecord {
            try .manual(72.9, at: "2026-09-24T07:00:00+09:00", in: "Asia/Tokyo")
        }

        static func question() throws -> SentText {
            try .fixture("次は何を食べたらいい？", sentAt: "2026-09-24T08:00:00+09:00")
        }

        static func days(
            weightRecords: [WeightRecord] = [], meals: [MealCard] = [],
            sentTexts: [SentText] = [], replies: [AiUtterance] = [], notices: [Notice] = []
        ) -> [Timeline.Day] {
            Timeline(
                input: Timeline.Input(
                    goalRecords: GoalRecords(
                        goals: [], dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                        weightTrend: nil, weightRecords: weightRecords), rejectedLines: [],
                    meals: meals, notices: notices, undelivered: .none,
                    conversation: Timeline.Conversation(
                        sentTexts: sentTexts,
                        statuses: Dictionary(
                            uniqueKeysWithValues: sentTexts.map {
                                (
                                    $0.id,
                                    SentTextStatus(classification: .conversation, reply: .replied)
                                )
                            }),
                        replies: replies, streams: [:])),
                firstDay: yesterday, today: today
            ).days
        }

        /// 送った文章が、いちばん下に足された前後の並び
        struct SentTextAddition {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let sentAt: Date

            init() throws {
                let morning = try ItemByUserAtEnd.morning()
                let question = try ItemByUserAtEnd.question()
                old = ItemByUserAtEnd.days(weightRecords: [morning])
                new = ItemByUserAtEnd.days(weightRecords: [morning], sentTexts: [question])
                sentAt = question.sentAt
            }
        }

        @Suite("送った文章がいちばん下に足され、今が送った時刻の1秒後のとき")
        struct SentTextAddedJustNow {
            let added: SentTextAddition
            let now: Date

            init() throws {
                added = try SentTextAddition()
                now = added.sentAt.addingTimeInterval(1)
            }

            @Test("足したとすること")
            func adds() {
                #expect(Timeline.addsItemByUserAtEnd(from: added.old, to: added.new, now: now))
            }
        }

        @Suite("送った文章がいちばん下に足され、今が送った時刻のちょうど1分後のとき")
        struct SentTextAddedAtWindowEnd {
            let added: SentTextAddition
            let now: Date

            init() throws {
                added = try SentTextAddition()
                now = added.sentAt.addingTimeInterval(60)
            }

            @Test("足したとすること")
            func adds() {
                #expect(Timeline.addsItemByUserAtEnd(from: added.old, to: added.new, now: now))
            }
        }

        @Suite("送った文章がいちばん下に足され、今が送った時刻から1分を過ぎているとき（ほかの端末で足したものが届いた）")
        struct SentTextAddedAfterWindow {
            let added: SentTextAddition
            let now: Date

            init() throws {
                added = try SentTextAddition()
                now = added.sentAt.addingTimeInterval(61)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: added.old, to: added.new, now: now))
            }
        }

        @Suite("送った文章がいちばん下に足され、送った時刻が今より先のとき（時計の進んだほかの端末で足したものが届いた）")
        struct SentTextAddedFromFuture {
            let added: SentTextAddition
            let now: Date

            init() throws {
                added = try SentTextAddition()
                now = added.sentAt.addingTimeInterval(-1)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: added.old, to: added.new, now: now))
            }
        }

        @Suite("手で入れた体重記録が、記録した直後にいちばん下に足されたとき")
        struct ManualWeightAdded {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let morning = try ItemByUserAtEnd.morning()
                let question = try ItemByUserAtEnd.question()
                let night = try WeightRecord.manual(
                    72.6, at: "2026-09-24T22:00:00+09:00", in: "Asia/Tokyo")
                old = ItemByUserAtEnd.days(weightRecords: [morning], sentTexts: [question])
                new = ItemByUserAtEnd.days(weightRecords: [morning, night], sentTexts: [question])
                now = night.instant.addingTimeInterval(1)
            }

            @Test("足したとすること")
            func adds() {
                #expect(Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("食事が、送った直後にいちばん下に足されたとき")
        struct MealAdded {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let morning = try ItemByUserAtEnd.morning()
                let lunch = try MealCard.fixture(
                    eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:30:00+09:00",
                    status: nil)
                old = ItemByUserAtEnd.days(weightRecords: [morning])
                new = ItemByUserAtEnd.days(weightRecords: [morning], meals: [lunch])
                now = lunch.meal.sentAt.addingTimeInterval(1)
            }

            @Test("足したとすること")
            func adds() {
                #expect(Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("今日に何も無く、前の日のいちばん下に足されたとき")
        struct AddedOnEarlierDay {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let lastNight = try WeightRecord.manual(
                    72.6, at: "2026-09-23T23:59:59+09:00", in: "Asia/Tokyo")
                old = ItemByUserAtEnd.days()
                new = ItemByUserAtEnd.days(weightRecords: [lastNight])
                // 日をまたいだ直後
                now = lastNight.instant.addingTimeInterval(1)
            }

            @Test("足したとすること")
            func adds() {
                #expect(Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("同じ時刻に並ぶ文章のうち、いちばん上に並ぶものが足されたとき")
        struct AddedAmongTied {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let tied = try (0..<8).map { _ in
                    try SentText.fixture("散歩した", sentAt: "2026-09-24T08:00:00+09:00")
                }
                // 同じ時刻の項目は ID の順に並ぶ
                let added = try #require(tied.min { $0.id.uuidString < $1.id.uuidString })
                old = ItemByUserAtEnd.days(sentTexts: tied.filter { $0 != added })
                new = ItemByUserAtEnd.days(sentTexts: tied)
                now = added.sentAt.addingTimeInterval(1)
            }

            @Test("足したとすること")
            func adds() {
                #expect(Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("あとの時刻の文章より前に足されたとき")
        struct AddedBeforeLater {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let question = try ItemByUserAtEnd.question()
                let earlier = try SentText.fixture(
                    "朝に歩いた", sentAt: "2026-09-24T07:59:30+09:00")
                old = ItemByUserAtEnd.days(sentTexts: [question])
                new = ItemByUserAtEnd.days(sentTexts: [earlier, question])
                now = earlier.sentAt.addingTimeInterval(1)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("ヘルスケアから取り込んだ体重が、いちばん下に足されたとき")
        struct ImportedWeightAdded {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let morning = try ItemByUserAtEnd.morning()
                let imported = try WeightRecord.imported(
                    72.6, at: "2026-09-24T22:00:00+09:00", in: "Asia/Tokyo")
                old = ItemByUserAtEnd.days(weightRecords: [morning])
                new = ItemByUserAtEnd.days(weightRecords: [morning, imported])
                now = imported.instant.addingTimeInterval(1)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("返事が、いちばん下に足されたとき")
        struct ReplyAdded {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let question = try ItemByUserAtEnd.question()
                let reply = AiUtterance(
                    id: UUID(), body: "野菜の多い定食はどうでしょう。", sentTextId: question.id,
                    mealIds: [])
                old = ItemByUserAtEnd.days(sentTexts: [question])
                new = ItemByUserAtEnd.days(sentTexts: [question], replies: [reply])
                now = question.sentAt.addingTimeInterval(1)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("知らせが、いちばん下に足されたとき")
        struct NoticeAdded {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let question = try ItemByUserAtEnd.question()
                let notice = try Notice.missedWeightRecord(issuedAt: "2026-09-24T08:00:30+09:00")
                old = ItemByUserAtEnd.days(sentTexts: [question])
                new = ItemByUserAtEnd.days(sentTexts: [question], notices: [notice])
                now = notice.issuedAt.addingTimeInterval(1)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("いちばん下が消えて、前からある記録がいちばん下になったとき")
        struct LastRemoved {
            let old: [Timeline.Day]
            let new: [Timeline.Day]
            let now: Date

            init() throws {
                let morning = try ItemByUserAtEnd.morning()
                let question = try ItemByUserAtEnd.question()
                old = ItemByUserAtEnd.days(weightRecords: [morning], sentTexts: [question])
                new = ItemByUserAtEnd.days(weightRecords: [morning])
                now = morning.instant.addingTimeInterval(1)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: old, to: new, now: now))
            }
        }

        @Suite("並びが変わらないとき")
        struct Unchanged {
            let days: [Timeline.Day]
            let now: Date

            init() throws {
                let question = try ItemByUserAtEnd.question()
                days = ItemByUserAtEnd.days(
                    weightRecords: [try ItemByUserAtEnd.morning()], sentTexts: [question])
                now = question.sentAt.addingTimeInterval(1)
            }

            @Test("足したとしないこと")
            func doesNotAdd() {
                #expect(!Timeline.addsItemByUserAtEnd(from: days, to: days, now: now))
            }
        }
    }
}
