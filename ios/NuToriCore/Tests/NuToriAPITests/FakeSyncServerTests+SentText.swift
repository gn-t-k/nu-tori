import Foundation
import Testing

@testable import NuToriAPI

extension FakeSyncServerTests {
    static let sentAt = Date(timeIntervalSince1970: 1_790_000_000)

    static func sentText(_ body: String) -> SyncedSentText {
        SyncedSentText(
            id: UUID(), body: body, sentAt: sentAt,
            timeZone: TimeZone(identifier: "Asia/Tokyo")!)
    }

    static func answers(_ body: String) -> FakeSyncServer.SentTextAnswer? {
        switch body {
        case "昼はうどん": .meal(replyAsConversation: "うどんの話ですね。")
        case "こんにちは": .reply("こんにちは。")
        case "次は？": .failsThenReply("野菜を足しましょう。")
        default: nil
        }
    }

    static func client(answerPulls: Int) -> NuToriAPIClient {
        client(
            .init(
                records: [], startedOn: startedOn, answerSentText: answers,
                sentTextAnswerPulls: answerPulls))
    }

    static func changes(_ result: NuToriAPIClient.PullSyncChangesResult) -> [SyncChange] {
        guard case .pulled(let page) = result else { return [] }
        return page.changes
    }

    static func next(_ result: NuToriAPIClient.PullSyncChangesResult) -> Int {
        guard case .pulled(let page) = result else { return 0 }
        return page.nextAfterSequence
    }

    static func status(_ changes: [SyncChange]) -> SyncedSentTextStatus? {
        changes.compactMap { if case .sentTextStatus(let status) = $0 { status } else { nil } }.last
    }

    @Suite("会話の文章を受け付けたとき")
    struct ConversationText {
        @Test("答えるまでの取得の回数までは読み分けを待ち、その回の取得で会話にして返事を返すこと")
        func repliesOnAnswerPull() async throws {
            let client = FakeSyncServerTests.client(answerPulls: 2)
            let sentText = FakeSyncServerTests.sentText("こんにちは")
            _ = try await client.pushSyncWrites(
                [.createSentText(writeId: UUID(), sentText: sentText)], isFinalBatch: true,
                clientState: .fixture())

            let first = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())
            let second = try await client.pullSyncChanges(
                afterSequence: FakeSyncServerTests.next(first), clientState: .fixture())

            #expect(
                FakeSyncServerTests.status(FakeSyncServerTests.changes(first))
                    == .init(
                        sentTextId: sentText.id, classification: .pending, reply: .notRequested))
            let replies = FakeSyncServerTests.changes(second).compactMap { change in
                if case .aiUtterance(let reply) = change { reply } else { nil }
            }
            #expect(replies.map(\.body) == ["こんにちは。"])
            #expect(replies.map(\.sentTextId) == [sentText.id])
            #expect(
                FakeSyncServerTests.status(FakeSyncServerTests.changes(second))
                    == .init(
                        sentTextId: sentText.id, classification: .conversation, reply: .replied))
        }
    }

    @Suite("食事の文章を受け付けたとき")
    struct MealText {
        @Test("送った時刻の文章の食事を推定中で作り、会話として送り直すと食事を消して返事を返すこと")
        func createsWrittenMealAndRepliesWhenResent() async throws {
            let client = FakeSyncServerTests.client(answerPulls: 1)
            let sentText = FakeSyncServerTests.sentText("昼はうどん")
            _ = try await client.pushSyncWrites(
                [.createSentText(writeId: UUID(), sentText: sentText)], isFinalBatch: true,
                clientState: .fixture())
            let classified = try await client.pullSyncChanges(
                afterSequence: 0, clientState: .fixture())
            let meals = FakeSyncServerTests.changes(classified).compactMap { change in
                if case .meal(let meal) = change { meal } else { nil }
            }
            _ = try await client.pushSyncWrites(
                [.resendSentTextAsConversation(writeId: UUID(), sentTextId: sentText.id)],
                isFinalBatch: true, clientState: .fixture())
            let resent = try await client.pullSyncChanges(
                afterSequence: FakeSyncServerTests.next(classified), clientState: .fixture())

            let meal = try #require(meals.first)
            #expect(meals.count == 1)
            #expect(meal.entryMethod == .written(sentTextId: sentText.id))
            #expect(meal.eatenAt == FakeSyncServerTests.sentAt)
            #expect(meal.photoIds.isEmpty)
            #expect(
                FakeSyncServerTests.changes(classified).contains(
                    .mealEstimationStatus(.init(mealId: meal.id, status: .estimating))))
            #expect(
                FakeSyncServerTests.status(FakeSyncServerTests.changes(classified))
                    == .init(sentTextId: sentText.id, classification: .meal, reply: .notRequested))
            #expect(FakeSyncServerTests.changes(resent).contains(.mealDeletion(mealId: meal.id)))
            #expect(
                FakeSyncServerTests.changes(resent).compactMap { change in
                    if case .aiUtterance(let reply) = change { reply.body } else { nil }
                } == ["うどんの話ですね。"])
        }
    }

    @Suite("1回めは返事を作れない文章を受け付けたとき")
    struct FailingText {
        @Test("作れなかったにし、送り直すと返事を返すこと")
        func failsThenRepliesWhenResent() async throws {
            let client = FakeSyncServerTests.client(answerPulls: 1)
            let sentText = FakeSyncServerTests.sentText("次は？")
            _ = try await client.pushSyncWrites(
                [.createSentText(writeId: UUID(), sentText: sentText)], isFinalBatch: true,
                clientState: .fixture())
            let failed = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())
            _ = try await client.pushSyncWrites(
                [.resendSentText(writeId: UUID(), sentTextId: sentText.id)], isFinalBatch: true,
                clientState: .fixture())
            let resent = try await client.pullSyncChanges(
                afterSequence: FakeSyncServerTests.next(failed), clientState: .fixture())

            #expect(
                FakeSyncServerTests.status(FakeSyncServerTests.changes(failed))
                    == .init(
                        sentTextId: sentText.id, classification: .conversation,
                        reply: .failed(.retriesExhausted)))
            #expect(
                FakeSyncServerTests.changes(resent).compactMap { change in
                    if case .aiUtterance(let reply) = change { reply.body } else { nil }
                } == ["野菜を足しましょう。"])
            #expect(
                FakeSyncServerTests.status(FakeSyncServerTests.changes(resent))
                    == .init(
                        sentTextId: sentText.id, classification: .conversation, reply: .replied))
        }
    }
}
