import Foundation
import NuToriCore
import Testing

extension SyncEngineTests {
    @Suite("同期の失敗を Sentry に送る")
    struct ReportingSyncFailures {
        struct SampleError: Error {}

        @Suite("時間切れのとき")
        struct TimedOut {
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine

            init() {
                reporting = .ok()
                engine = .fixture(
                    store: .ok(),
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

            init() {
                reporting = .ok()
                engine = .fixture(
                    store: .ok(),
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
    }
}
