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

    @Suite("キャッシュの保存に失敗したとき")
    struct CacheSaveFailure {
        struct SampleError: Error {}

        let reporting: ErrorReportingSessionMock
        let engine: HealthSyncEngine

        init() throws {
            reporting = .ok()
            let record = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            engine = .fixture(
                healthStore: .ok(),
                store: .error(SampleError(), records: [record], writesOnly: true),
                errorReporting: reporting
            )
        }

        @Test("キャッシュの保存の失敗として送り、失敗を呼び出し側に返すこと")
        func reportsCacheSave() async {
            await #expect(throws: SampleError.self) {
                try await engine.exportCachedManualRecordsOnNewWriteAuthorization()
            }
            #expect(reporting.reported == [.cacheSave])
        }
    }
}
