import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("タイムラインに出す、受け付けなかった1行")
struct RejectedLinesTests {
    @Suite("体重の書き込みを受け付けなかったとき")
    struct WeightRejected {
        let created: WeightRecord
        let corrected: WeightRecord
        var rejected = RejectedLines()

        init() throws {
            created = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 1)
            corrected = try WeightRecord.manual(
                71.9, at: "2026-09-24T08:00:00+09:00", in: "Asia/Tokyo", version: 2)
            rejected.add([
                .weight(created, serverHasValue: false),
                .weight(corrected, serverHasValue: true),
            ])
        }

        @Test("サーバーに値が無い記録は記録の代わりに、値がある記録はそのすぐ下に1行を出すこと")
        func addsWeightLines() throws {
            #expect(rejected.lines.count == 2)
            let createdLine = try #require(rejected.lines.first?.weightLine)
            let correctedLine = try #require(rejected.lines.last?.weightLine)
            #expect(createdLine.record == created)
            #expect(createdLine.placement == .insteadOfRecord)
            #expect(correctedLine.record == corrected)
            #expect(correctedLine.placement == .belowRecord)
        }
    }

    @Suite("食事の書き込みを受け付けなかったとき")
    struct MealRejected {
        let meal: Meal
        var rejected = RejectedLines()

        init() throws {
            meal = try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            rejected.add([.meal(meal)])
        }

        @Test("その食事の1行を出すこと")
        func addsMealLine() {
            #expect(rejected.lines == [.meal(RejectedMealLine(meal: meal))])
        }
    }

    @Suite("送った文章の書き込みを受け付けなかったとき")
    struct SentTextRejected {
        let longText: SentText
        let shortText: SentText

        init() throws {
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            // 2026-09-22 13:05（東京）
            let sentAt = Date(timeIntervalSince1970: 1_790_049_900)
            longText = SentText(
                id: UUID(), body: "朝はトーストと牛乳、昼はうどん、夜はカレー", sentAt: sentAt,
                timeZone: tokyo)
            shortText = SentText(
                id: UUID(), body: "朝はトーストと牛乳、昼はうどん", sentAt: sentAt, timeZone: tokyo)
        }

        @Test("文章を送れなかった行は、送った時刻と最初の 15 字に … を付けて、吹き出しを外した位置に出すこと")
        func sendLineWithOpening() {
            let line = RejectedSentTextLine(sentText: longText, subject: .send)

            #expect(line.text == "13:05 の「朝はトーストと牛乳、昼はうどん…」は、送れませんでした。")
            #expect(line.placement == .insteadOfBubble)
        }

        @Test("15 字以下の文章を送れなかった行は、全文を入れて … を付けないこと")
        func sendLineWithWholeBody() {
            let line = RejectedSentTextLine(sentText: shortText, subject: .send)

            #expect(line.text == "13:05 の「朝はトーストと牛乳、昼はうどん」は、送れませんでした。")
        }

        @Test("会話として送り直せなかった行は、吹き出しの下に出すこと")
        func resendAsConversationLine() {
            let line = RejectedSentTextLine(sentText: longText, subject: .resendAsConversation)

            #expect(line.text == "会話として送り直せませんでした。")
            #expect(line.placement == .belowBubble)
        }

        @Test("送り直せなかった行は、吹き出しの下に出すこと")
        func resendLine() {
            let line = RejectedSentTextLine(sentText: longText, subject: .resend)

            #expect(line.text == "送り直せませんでした。")
            #expect(line.placement == .belowBubble)
        }

        @Test("同じ文章の行は、新しい1行に置き換えること")
        func replacesLineOfSameSentText() {
            var rejected = RejectedLines()

            rejected.add([.sentText(longText, .resendAsConversation)])
            rejected.add([.sentText(longText, .resend)])

            #expect(
                rejected.lines == [
                    .sentText(RejectedSentTextLine(sentText: longText, subject: .resend))
                ])
        }
    }

    @Suite("同じ記録を2回続けて受け付けなかったとき")
    struct RejectedTwice {
        let first: WeightRecord
        let second: WeightRecord
        let meal: Meal
        var rejected = RejectedLines()

        init() throws {
            let id = UUID()
            first = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", id: id, version: 1)
            second = try WeightRecord.manual(
                72.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", id: id, version: 2)
            meal = try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            rejected.add([.weight(first, serverHasValue: false), .meal(meal)])
            rejected.add([.weight(second, serverHasValue: true), .meal(meal)])
        }

        @Test("古い1行を消して、新しい1行だけを出すこと")
        func replacesTheLine() {
            #expect(
                rejected.lines == [
                    .weight(RejectedWeightLine(record: second, serverHasValue: true)),
                    .meal(RejectedMealLine(meal: meal)),
                ])
        }
    }

    @Suite("体重と食事の1行が2つずつあるとき")
    struct WeightsAndMeals {
        let keptWeight: WeightRecord
        let droppedWeight: WeightRecord
        let keptMeal: Meal
        let droppedMeal: Meal
        var rejected = RejectedLines()

        init() throws {
            keptWeight = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            droppedWeight = try WeightRecord.manual(
                71.9, at: "2026-09-24T08:00:00+09:00", in: "Asia/Tokyo")
            keptMeal = try .fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
            droppedMeal = try .fixture(
                eatenAt: "2026-09-24T19:00:00+09:00", sentAt: "2026-09-24T19:01:00+09:00")
            rejected.add([
                .weight(keptWeight, serverHasValue: false),
                .weight(droppedWeight, serverHasValue: true),
                .meal(keptMeal),
                .meal(droppedMeal),
            ])
        }

        @Test("記録の ID で消すと、体重でも食事でもその1行だけが消えること")
        mutating func removesByRecordId() {
            rejected.remove(recordId: droppedWeight.id)
            rejected.remove(recordId: droppedMeal.id)

            #expect(
                rejected.lines == [
                    .weight(RejectedWeightLine(record: keptWeight, serverHasValue: false)),
                    .meal(RejectedMealLine(meal: keptMeal)),
                ])
        }

        @Test("全部捨てると、1行が無くなること")
        mutating func removesAll() {
            rejected.removeAll()

            #expect(rejected.lines.isEmpty)
        }
    }
}

extension RejectedWrite {
    fileprivate static func weight(_ record: WeightRecord, serverHasValue: Bool) -> RejectedWrite {
        RejectedWrite(
            writeId: UUID(), reason: .outOfRange,
            record: .weightRecord(record, serverHasValue: serverHasValue))
    }

    fileprivate static func meal(_ meal: Meal) -> RejectedWrite {
        RejectedWrite(writeId: UUID(), reason: .recordNotFound, record: .meal(meal))
    }

    fileprivate static func sentText(
        _ sentText: SentText, _ subject: RejectedSentTextLine.Subject
    ) -> RejectedWrite {
        RejectedWrite(
            writeId: UUID(), reason: .replyNotFailed,
            record: .sentText(RejectedSentTextLine(sentText: sentText, subject: subject)))
    }
}
