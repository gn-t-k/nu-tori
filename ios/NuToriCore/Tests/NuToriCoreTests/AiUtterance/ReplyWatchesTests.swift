import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Synchronization
import Testing

@Suite("見守る要求をつなぐ")
struct ReplyWatchesTests {
    /// 見守る要求の知らせ（途中の返事、閉じた）を、届いた順に受け取る
    final class Observer: Sendable {
        enum Note: Equatable {
            case streams([UUID: ReplyStream])
            case closed
        }

        let notes: AsyncStream<Note>
        private let continuation: AsyncStream<Note>.Continuation

        init() {
            (notes, continuation) = AsyncStream.makeStream()
        }

        func watches(_ transport: ClientTransportMock) -> ReplyWatches {
            let client = NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!, transport: transport,
                appBuildGate: .sample, sessionToken: { "session-1" })
            return ReplyWatches(
                watch: { try await client.watchReply(sentTextId: $0) },
                onStreams: { self.continuation.yield(.streams($0)) },
                onClosed: { self.continuation.yield(.closed) })
        }

        /// 条件に合う知らせが届くまで待つ
        func next(where matches: (Note) -> Bool) async -> Note? {
            for await note in notes where matches(note) {
                return note
            }
            return nil
        }

        func nextClosed() async {
            _ = await next { $0 == .closed }
        }

        func nextStreams(where matches: ([UUID: ReplyStream]) -> Bool) async -> [UUID: ReplyStream]?
        {
            let note = await next { note in
                if case .streams(let streams) = note { matches(streams) } else { false }
            }
            if case .streams(let streams) = note { return streams }
            return nil
        }
    }

    @Suite("返事を流しているあいだ")
    struct Streaming {
        let observer: Observer
        let feed: AsyncStream<String>.Continuation
        let transport: ClientTransportMock
        let watches: ReplyWatches
        let sentTextId = UUID()
        let replyId = UUID()

        init() {
            observer = Observer()
            let (data, feed) = AsyncStream<String>.makeStream()
            self.feed = feed
            transport = .replyStream(data: data)
            watches = observer.watches(transport)
        }

        @Test("つながっているとし、できた分を途中の返事として知らせること")
        func publishesGrowingText() async throws {
            await watches.follow(awaiting: [sentTextId])
            feed.yield(#"{"type":"reply_started","replyId":"\#(replyId.uuidString)"}"#)
            feed.yield(#"{"type":"text_delta","text":"野菜の"}"#)
            let streams = await observer.nextStreams { $0[sentTextId]?.text == "野菜の" }

            #expect(streams?[sentTextId]?.replyId == replyId)
            #expect(await watches.connectedSentTextIds == [sentTextId])
            feed.finish()
        }

        @Test("同じ文章をもう一度つながないこと")
        func doesNotConnectTwice() async throws {
            await watches.follow(awaiting: [sentTextId])
            feed.yield(#"{"type":"text_delta","text":"野菜の"}"#)
            _ = await observer.nextStreams { $0[sentTextId]?.text == "野菜の" }
            await watches.follow(awaiting: [sentTextId])

            #expect(transport.requests.count == 1)
            feed.finish()
        }
    }

    @Suite("結果を受け取って閉じたとき")
    struct ClosedWithOutcome {
        let observer: Observer
        let transport: ClientTransportMock
        let watches: ReplyWatches
        let sentTextId = UUID()

        init() async {
            observer = Observer()
            transport = .replyStream(data: [
                #"{"type":"text_delta","text":"どうぞ"}"#,
                #"{"type":"replied","replyId":"\#(UUID().uuidString)"}"#,
            ])
            watches = observer.watches(transport)
            await watches.follow(awaiting: [sentTextId])
            await observer.nextClosed()
        }

        @Test("閉じたことを知らせ（取りに行くため）、つながっていないとすること")
        func reportsClosed() async {
            #expect(await watches.connectedSentTextIds.isEmpty)
        }

        @Test("取りに行くまで応答を待っていても、つなぎ直さないこと")
        func doesNotReconnect() async {
            await watches.follow(awaiting: [sentTextId])
            #expect(transport.requests.count == 1)
        }

        @Test("応答を待たなくなったら、途中の返事を捨てること")
        func dropsStreamWhenSettled() async {
            await watches.follow(awaiting: [])
            let streams = await observer.nextStreams { $0[sentTextId] == nil }
            #expect(streams == [:])
        }
    }

    @Suite("結果を受け取って閉じた文章が、応答を待たなくなったあとで再び応答を待つようになったとき（送り直した）")
    struct ResentAfterOutcome {
        let observer: Observer
        let transport: ClientTransportMock
        let watches: ReplyWatches
        let sentTextId = UUID()

        init() async {
            observer = Observer()
            transport = .replyStream(data: [
                #"{"type":"replied","replyId":"\#(UUID().uuidString)"}"#
            ])
            watches = observer.watches(transport)
            await watches.follow(awaiting: [sentTextId])
            await observer.nextClosed()
            await watches.follow(awaiting: [])
        }

        @Test("つなぎ直すこと")
        func reconnects() async {
            await watches.follow(awaiting: [sentTextId])
            await observer.nextClosed()
            #expect(transport.requests.count == 2)
        }
    }

    @Suite("結果を受け取らずに閉じたとき")
    struct ClosedWithoutOutcome {
        let observer: Observer
        let transport: ClientTransportMock
        let watches: ReplyWatches
        let sentTextId = UUID()

        init() async {
            observer = Observer()
            transport = .replyStream(data: [#"{"type":"text_delta","text":"どうぞ"}"#])
            watches = observer.watches(transport)
            await watches.follow(awaiting: [sentTextId])
            await observer.nextClosed()
        }

        @Test("閉じたことを知らせ、まだ応答を待っていれば、つなぎ直すこと")
        func reconnects() async {
            await watches.follow(awaiting: [sentTextId])
            await observer.nextClosed()

            #expect(transport.requests.count == 2)
        }
    }

    @Suite("つながらなかったとき")
    struct NotConnected {
        let observer: Observer
        let transport: ClientTransportMock
        let watches: ReplyWatches
        let sentTextId = UUID()

        init() async {
            observer = Observer()
            transport = .error(URLError(.notConnectedToInternet))
            watches = observer.watches(transport)
            await watches.follow(awaiting: [sentTextId])
            await observer.nextClosed()
        }

        @Test("閉じたことを知らせ（取りに行くため）、まだ応答を待っていても、つなぎ直さないこと")
        func reportsClosedWithoutReconnecting() async {
            await watches.follow(awaiting: [sentTextId])

            #expect(transport.requests.count == 1)
            #expect(await watches.connectedSentTextIds.isEmpty)
        }

        @Test("すべて切ったあとに応答を待つ文章を渡されたら、つなぐこと")
        func reconnectsAfterStopAll() async {
            await watches.stopAll()
            await watches.follow(awaiting: [sentTextId])
            await observer.nextClosed()

            #expect(transport.requests.count == 2)
        }
    }
}
