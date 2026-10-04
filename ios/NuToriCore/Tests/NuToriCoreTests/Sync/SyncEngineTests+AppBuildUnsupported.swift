import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("締め出されたとき（サーバーが 426 を返したとき）")
    struct AppBuildUnsupported {
        @Suite("送り待ちを送ったとき")
        struct Pushing {
            let store: SyncBoxMock<RecordCacheMock>
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine
            let pending: PendingWeightRecordWrite

            init() throws {
                let record = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                pending = .creating(record)
                store = try .ok(records: [record], pendingWeightRecordWrites: [pending])
                reporting = .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pushStatus: HTTPResponse.Status(code: 426)),
                    errorReporting: reporting
                )
            }

            @Test("送り待ちを残すこと")
            func keepsPending() async throws {
                _ = try await engine.sync()

                #expect(store.pendingWeightRecords == [pending])
            }

            @Test("受け付けなかった行を出さず、締め出されたとして同期を止めること")
            func stopsWithoutRejection() async throws {
                let result = try await engine.sync()

                #expect(
                    result
                        == SyncResult(
                            rejectedWrites: [], ending: .stopped(.appBuildUnsupported)))
            }

            @Test("Sentry に送らないこと")
            func doesNotReport() async throws {
                _ = try await engine.sync()

                #expect(reporting.reported.isEmpty)
            }
        }

        @Suite("変更を取りに行ったとき")
        struct Pulling {
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine

            init() throws {
                reporting = .ok()
                engine = .fixture(
                    store: try .ok(),
                    transport: .ok(status: HTTPResponse.Status(code: 426)),
                    errorReporting: reporting
                )
            }

            @Test("締め出されたとして同期を止め、Sentry に送らないこと")
            func stopsWithoutReporting() async throws {
                let result = try await engine.sync()

                #expect(result.ending == .stopped(.appBuildUnsupported))
                #expect(reporting.reported.isEmpty)
            }
        }
    }
}
