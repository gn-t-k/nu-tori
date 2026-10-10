import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("受け付けなかった送った文章の1行の置き場")
    struct RejectedSentText {
        static let day = CalendarDay(year: 2026, month: 9, day: 24)

        @Test("送れなかった文章は、吹き出しを外した位置（送った時刻）に1行だけを置くこと")
        func placesSendLineInsteadOfBubble() throws {
            let morning = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            let evening = try WeightRecord.manual(
                72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
            let line = RejectedSentTextLine(
                sentText: try .fixture("昼はうどん", sentAt: "2026-09-24T12:11:00+09:00"),
                subject: .send)
            let timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [morning, evening], rejectedLines: [.sentText(line)],
                    meals: [], notices: []),
                firstDay: Self.day, today: Self.day)
            #expect(
                timeline.days.map(\.items) == [
                    [.weightRecord(morning), .rejectedSentTextLine(line), .weightRecord(evening)]
                ])
        }

        @Test("送り直せなかった文章は、吹き出しの下に1行を添えること")
        func attachesResendLineToBubble() throws {
            let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            let line = RejectedSentTextLine(sentText: sentText, subject: .resend)
            let failed = SentTextStatus(
                classification: .conversation, reply: .failed(.retriesExhausted))
            let timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [], rejectedLines: [.sentText(line)], meals: [], notices: [],
                    conversation: Timeline.Conversation(
                        sentTexts: [sentText], statuses: [sentText.id: failed])),
                firstDay: Self.day, today: Self.day)
            #expect(
                timeline.days.map(\.items) == [
                    [
                        .sentText(
                            SentTextBubble(
                                sentText: sentText, replyLine: .failed(.retriesExhausted),
                                rejectedLine: line))
                    ]
                ])
        }
    }
}
