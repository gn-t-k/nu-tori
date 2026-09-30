import Foundation
import NuToriCore
import Testing

extension HealthSyncEngineTests {
    @Suite("読み取りの失敗を Sentry に送る")
    struct ReportingReadFailures {
        struct SampleError: Error {}

        @Suite("時間切れのとき")
        struct TimedOut {
            let reporting: ErrorReportingSessionMock
            let engine: HealthSyncEngine

            init() {
                reporting = .ok()
                engine = .fixture(
                    healthStore: .error(URLError(.timedOut)),
                    store: .ok(),
                    errorReporting: reporting
                )
            }

            @Test("送らず、失敗を呼び出し側に返すこと")
            func doesNotReport() async {
                await #expect(throws: URLError.self) {
                    try await engine.importChanges()
                }
                #expect(reporting.reported.isEmpty)
            }
        }

        @Suite("時間切れ以外のとき")
        struct OtherFailure {
            let reporting: ErrorReportingSessionMock
            let engine: HealthSyncEngine

            init() {
                reporting = .ok()
                engine = .fixture(
                    healthStore: .error(SampleError()),
                    store: .ok(),
                    errorReporting: reporting
                )
            }

            @Test("読み取りの失敗として送ること")
            func reportsHealthRead() async {
                await #expect(throws: SampleError.self) {
                    try await engine.importChanges()
                }
                #expect(reporting.reported == [.healthRead])
            }
        }
    }
}
