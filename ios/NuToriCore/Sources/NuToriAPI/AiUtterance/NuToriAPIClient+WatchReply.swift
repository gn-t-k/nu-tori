public import Foundation
public import OpenAPIRuntime

extension NuToriAPIClient {
    /// 送った文章の見守る要求につなぐ。つながったら、閉じるまで出来事を届いた順に流す。
    /// 届け方の正本は同期なので、閉じたら（理由によらず）取りに行く
    public func watchReply(sentTextId: UUID) async throws -> WatchReplyResult {
        let output = try await client.watchReply(
            path: .init(sentTextId: sentTextId.canonicalString))
        switch output {
        case .ok(let ok):
            return .watching(ReplyStreamEvents(body: try ok.body.textEventStream))
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .sessionExpired
        case .notFound:
            return .notReceived
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    public enum WatchReplyResult: Sendable {
        case watching(ReplyStreamEvents)
        case badRequest
        case sessionExpired
        /// サーバーがまだ送った文章を受け取っていない
        case notReceived
        case rateLimited
    }

    /// 見守る要求で届く出来事の並び。サーバーが閉じると終わる
    public struct ReplyStreamEvents: AsyncSequence, Sendable {
        public typealias Element = ReplyStreamEvent

        let body: HTTPBody

        public func makeAsyncIterator() -> Iterator {
            Iterator(upstream: body.asDecodedServerSentEvents().makeAsyncIterator())
        }

        public struct Iterator: AsyncIteratorProtocol {
            typealias Lines = ServerSentEventsLineDeserializationSequence<HTTPBody>

            var upstream:
                ServerSentEventsDeserializationSequence<Lines>.Iterator<
                    Lines.Iterator<HTTPBody.AsyncIterator>
                >

            /// 読めない出来事（知らない種類、壊れた JSON）は読み飛ばす。サーバーが種類を足しても、出回っている版のアプリが止まらないため
            @concurrent public mutating func next() async throws -> ReplyStreamEvent? {
                while let event = try await upstream.next() {
                    guard let data = event.data,
                        let decoded = try? JSONDecoder().decode(
                            Components.Schemas.ReplyStreamEvent.self, from: Data(data.utf8)),
                        let replyEvent = try? ReplyStreamEvent(decoded)
                    else { continue }
                    return replyEvent
                }
                return nil
            }
        }
    }
}
