import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("同期の失敗を Sentry に送る")
    struct ReportingSyncFailures {
        struct SampleError: Error {}

        @Suite("時間切れのとき")
        struct TimedOut {
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine

            init() throws {
                reporting = .ok()
                engine = .fixture(
                    store: try .ok(),
                    transport: .error(URLError(.timedOut)),
                    errorReporting: reporting
                )
            }

            @Test("送らず、同期を止めること")
            func doesNotReport() async throws {
                let result = try await engine.sync()

                #expect(result.ending == .stopped(.unavailable))
                #expect(reporting.reported.isEmpty)
            }
        }

        @Suite("時間切れ以外のとき")
        struct OtherFailure {
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine

            init() throws {
                reporting = .ok()
                engine = .fixture(
                    store: try .ok(),
                    transport: .error(SampleError()),
                    errorReporting: reporting
                )
            }

            @Test("同期の失敗として送ること")
            func reportsSync() async throws {
                _ = try await engine.sync()

                #expect(reporting.reported == [.sync])
            }
        }

        @Suite("要求が通信の失敗で終わったとき")
        struct TransportFailure {
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine

            init() throws {
                reporting = .ok()
                engine = .fixture(
                    store: try .ok(),
                    transport: .error(URLError(.badServerResponse)),
                    errorReporting: reporting
                )
            }

            @Test("クライアントが包んだ通信の失敗のドメインとコードを添えること")
            func attachesUnderlyingCause() async throws {
                _ = try await engine.sync()

                let cause = try #require(reporting.reports.first?.cause)
                #expect(cause.domain == NSURLErrorDomain)
                #expect(cause.code == URLError.Code.badServerResponse.rawValue)
            }
        }
    }
}
