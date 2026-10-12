import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("ユーザーがアプリの中でいちばん下に足したか")
    struct ItemByUserAtEnd {
        static let yesterday = CalendarDay(year: 2026, month: 9, day: 23)
        static let today = CalendarDay(year: 2026, month: 9, day: 24)

        let morning: WeightRecord
        let question: SentText

        init() throws {
            morning = try .manual(72.9, at: "2026-09-24T07:00:00+09:00", in: "Asia/Tokyo")
            question = try .fixture("次は何を食べたらいい？", sentAt: "2026-09-24T08:00:00+09:00")
        }

        /// 足した直後（並ぶ時刻のすぐあと）に確かめる
        static func adds(
            from old: [Timeline.Day], to new: [Timeline.Day], secondsAfterPlaced: TimeInterval = 1
        ) -> Bool {
            let placedAt = new.flatMap(\.items).compactMap { item -> Date? in
                switch item {
                case .weightRecord(let record): record.instant
                case .sentText(let bubble): bubble.sentText.sentAt
                default: nil
                }
            }.filter { instant in
                !old.flatMap(\.items).contains { item in
                    switch item {
                    case .weightRecord(let record): record.instant == instant
                    case .sentText(let bubble): bubble.sentText.sentAt == instant
                    default: false
                    }
                }
            }.max()
            let now = (placedAt ?? Date(timeIntervalSince1970: 0)).addingTimeInterval(
                secondsAfterPlaced)
            return Timeline.addsItemByUserAtEnd(from: old, to: new, now: now)
        }

        static func days(
            weightRecords: [WeightRecord] = [], sentTexts: [SentText] = [],
            replies: [AiUtterance] = [], notices: [Notice] = []
        ) -> [Timeline.Day] {
            Timeline(
                input: Timeline.Input(
                    weightRecords: weightRecords, rejectedLines: [], meals: [], notices: notices,
                    undelivered: .none,
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

        @Test("送った文章がいちばん下に足されたら、足されたとすること")
        func sentTextAdded() {
            let old = Self.days(weightRecords: [morning])
            let new = Self.days(weightRecords: [morning], sentTexts: [question])
            #expect(Self.adds(from: old, to: new))
        }

        @Test("体重記録がいちばん下に足されたら、足されたとすること")
        func weightRecordAdded() throws {
            let night = try WeightRecord.manual(
                72.6, at: "2026-09-24T22:00:00+09:00", in: "Asia/Tokyo")
            let old = Self.days(weightRecords: [morning], sentTexts: [question])
            let new = Self.days(weightRecords: [morning, night], sentTexts: [question])
            #expect(Self.adds(from: old, to: new))
        }

        @Test("今日に何も無いとき、前の日のいちばん下に足されたら、足されたとすること")
        func addedOnEarlierDay() throws {
            let lastNight = try WeightRecord.manual(
                72.6, at: "2026-09-23T22:00:00+09:00", in: "Asia/Tokyo")
            let new = Self.days(weightRecords: [lastNight])
            #expect(Self.adds(from: Self.days(), to: new))
        }

        @Test("同じ時刻に並ぶ文章のあいだに足されても、足されたとすること")
        func addedAmongTied() throws {
            let tied = try (0..<8).map { _ in
                try SentText.fixture("散歩した", sentAt: "2026-09-24T08:00:00+09:00")
            }
            for added in tied {
                let old = Self.days(
                    weightRecords: [morning], sentTexts: tied.filter { $0 != added })
                let new = Self.days(weightRecords: [morning], sentTexts: tied)
                #expect(Self.adds(from: old, to: new))
            }
        }

        @Test("あとの時刻の記録より前に足されたら、足されたとしないこと")
        func addedBeforeLater() throws {
            let earlier = try SentText.fixture("朝に歩いた", sentAt: "2026-09-24T06:00:00+09:00")
            let old = Self.days(weightRecords: [morning], sentTexts: [question])
            let new = Self.days(weightRecords: [morning], sentTexts: [earlier, question])
            #expect(!Self.adds(from: old, to: new))
        }

        @Test("ヘルスケアから取り込んだ体重がいちばん下に足されても、足されたとしないこと")
        func importedWeightAdded() throws {
            let imported = try WeightRecord.imported(
                72.6, at: "2026-09-24T22:00:00+09:00", in: "Asia/Tokyo")
            let old = Self.days(weightRecords: [morning])
            let new = Self.days(weightRecords: [morning, imported])
            #expect(
                !Timeline.addsItemByUserAtEnd(
                    from: old, to: new, now: imported.instant.addingTimeInterval(1)))
        }

        @Test("並ぶ時刻から1分より後に足されたら（ほかの端末で足したものが届いた）、足されたとしないこと")
        func arrivedLater() {
            let old = Self.days(weightRecords: [morning])
            let new = Self.days(weightRecords: [morning], sentTexts: [question])
            #expect(Self.adds(from: old, to: new, secondsAfterPlaced: 60))
            #expect(!Self.adds(from: old, to: new, secondsAfterPlaced: 61))
        }

        @Test("途中に足されたら、足されたとしないこと")
        func addedInMiddle() throws {
            let lastNight = try WeightRecord.manual(
                72.6, at: "2026-09-23T22:00:00+09:00", in: "Asia/Tokyo")
            let old = Self.days(weightRecords: [morning])
            let new = Self.days(weightRecords: [lastNight, morning])
            #expect(!Self.adds(from: old, to: new))
        }

        @Test("返事がいちばん下に足されても、足されたとしないこと")
        func replyAdded() {
            let reply = AiUtterance(
                id: UUID(), body: "野菜の多い定食はどうでしょう。", sentTextId: question.id, mealIds: [])
            let old = Self.days(sentTexts: [question])
            let new = Self.days(sentTexts: [question], replies: [reply])
            #expect(!Self.adds(from: old, to: new))
        }

        @Test("知らせがいちばん下に足されても、足されたとしないこと")
        func noticeAdded() throws {
            let notice = try Notice.missedWeightRecord(issuedAt: "2026-09-24T21:00:00+09:00")
            let old = Self.days(sentTexts: [question])
            let new = Self.days(sentTexts: [question], notices: [notice])
            #expect(!Self.adds(from: old, to: new))
        }

        @Test("いちばん下が消えて前からある記録がいちばん下になっても、足されたとしないこと")
        func lastRemoved() {
            let old = Self.days(weightRecords: [morning], sentTexts: [question])
            let new = Self.days(weightRecords: [morning])
            #expect(!Self.adds(from: old, to: new))
        }

        @Test("並びが変わらないときは、足されたとしないこと")
        func unchanged() {
            let days = Self.days(weightRecords: [morning], sentTexts: [question])
            #expect(!Self.adds(from: days, to: days))
        }
    }
}
