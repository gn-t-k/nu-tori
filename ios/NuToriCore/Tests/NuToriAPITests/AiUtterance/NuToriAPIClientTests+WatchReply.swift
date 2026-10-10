import Foundation
import HTTPTypes
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("見守る要求")
    struct WatchReply {
        static func client(_ transport: ClientTransportMock) -> NuToriAPIClient {
            NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            )
        }

        static func events(_ result: NuToriAPIClient.WatchReplyResult) async throws
            -> [ReplyStreamEvent]
        {
            guard case .watching(let events) = result else {
                Issue.record("つながらなかった: \(result)")
                return []
            }
            var received: [ReplyStreamEvent] = []
            for try await event in events {
                received.append(event)
            }
            return received
        }

        @Suite("つながったとき")
        struct Connected {
            let sentTextId = UUID()
            let replyId = UUID()
            let transport: ClientTransportMock

            init() {
                transport = .replyStream(data: [
                    #"{"type":"reply_started","replyId":"\#(replyId.canonicalString)"}"#,
                    #"{"type":"text_delta","text":"野菜の"}"#,
                    #"{"type":"text_discarded"}"#,
                    #"{"type":"text_delta","text":"野菜の多い"}"#,
                    #"{"type":"replied","replyId":"\#(replyId.canonicalString)"}"#,
                ])
            }

            @Test("その文章の見守る要求の経路につなぐこと")
            func requestsReplyStream() async throws {
                _ = try await WatchReply.events(
                    WatchReply.client(transport).watchReply(sentTextId: sentTextId))
                let sent = try #require(transport.requests.first)
                #expect(sent.request.method == .get)
                #expect(
                    sent.request.path
                        == "/v1/sent-texts/\(sentTextId.canonicalString)/reply-stream")
            }

            @Test("ID、できた分、流し直しの知らせ、結果を届いた順に読むこと")
            func readsEventsInOrder() async throws {
                let events = try await WatchReply.events(
                    WatchReply.client(transport).watchReply(sentTextId: sentTextId))
                #expect(
                    events == [
                        .replyStarted(replyId: replyId), .textDelta("野菜の"), .textDiscarded,
                        .textDelta("野菜の多い"), .replied(replyId: replyId),
                    ])
            }
        }

        @Suite("結果だけが届いたとき")
        struct OutcomeOnly {
            @Test("食事・回数切れ・作れなかったの結果を読むこと")
            func readsOutcomes() async throws {
                let transport = ClientTransportMock.replyStream(data: [
                    #"{"type":"classified_as_meal"}"#,
                    #"{"type":"reply_halted"}"#,
                    #"{"type":"reply_failed","failureReason":"bad_request"}"#,
                ])
                let events = try await WatchReply.events(
                    WatchReply.client(transport).watchReply(sentTextId: UUID()))
                #expect(events == [.classifiedAsMeal, .replyHalted, .replyFailed(.badRequest)])
            }
        }

        @Suite("知らない種類の出来事が届いたとき")
        struct UnknownEvent {
            @Test("読み飛ばして、続く出来事を読むこと")
            func skipsUnknown() async throws {
                let transport = ClientTransportMock.replyStream(data: [
                    #"{"type":"heartbeat"}"#,
                    #"{"type":"text_delta","text":"どうぞ"}"#,
                ])
                let events = try await WatchReply.events(
                    WatchReply.client(transport).watchReply(sentTextId: UUID()))
                #expect(events == [.textDelta("どうぞ")])
            }
        }

        @Suite("サーバーがまだ文章を受け取っていないとき")
        struct NotReceived {
            @Test("受け取っていないと返すこと")
            func returnsNotReceived() async throws {
                let result = try await WatchReply.client(.ok(status: .notFound)).watchReply(
                    sentTextId: UUID())
                guard case .notReceived = result else {
                    Issue.record("受け取っていないと返さなかった: \(result)")
                    return
                }
            }
        }
    }
}
