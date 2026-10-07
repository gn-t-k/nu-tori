import Foundation
import HTTPTypes
import NuToriTestSupport
import OpenAPIRuntime
import Testing

@testable import NuToriAPI

extension FakeSyncServerTests {
    @Suite("ID が小文字の正規形でない要求を受けたとき")
    struct NonCanonicalId {
        let dish: SyncedDish
        let server: FakeSyncServer
        let client: NuToriAPIClient
        let baseURL: URL
        let uppercasedWriteRequest: HTTPRequest
        let uppercasedWriteBody: Data
        let uppercasedPullRequest: HTTPRequest

        init() throws {
            let dish = try SyncedDish.fixture(mealId: try SyncedMeal.fixture().id)
            let baseURL = try #require(URL(string: "https://api.example"))
            let server = FakeSyncServer(
                .init(records: [.dish(dish)], startedOn: FakeSyncServerTests.startedOn))
            self.dish = dish
            self.server = server
            self.baseURL = baseURL
            // 大文字の要求を直に送るのと、取りに行くのを、同じ偽のサーバーに向ける
            client = NuToriAPIClient(
                serverURL: baseURL,
                transport: server,
                appBuildGate: .sample,
                sessionToken: { FakeSyncServer.sessionToken }
            )
            uppercasedWriteRequest = HTTPRequest(
                method: .post, scheme: "https", authority: "api.example", path: "/v1/sync/writes")
            uppercasedWriteBody = try JSONEncoder().encode(
                PushSyncWritesPayload(
                    clientState: .init(
                        deviceId: "00000000-0000-4000-8000-0000000000d1", timeZone: "Asia/Tokyo",
                        appVersion: "1.0.0", osVersion: "26.0", pendingWriteCount: 1,
                        pendingPhotoCount: 0),
                    writes: [
                        .deleteDish(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a1", _type: .deleteDish,
                                dishId: "00000000-0000-4000-8000-0000000000E2"))
                    ],
                    isFinalBatch: true))
            uppercasedPullRequest = HTTPRequest(
                method: .get, scheme: "https", authority: "api.example",
                path:
                    "/v1/sync/changes?deviceId=00000000-0000-4000-8000-0000000000D1&afterSequence=0"
            )
        }

        @Test("大文字の ID で料理を名指しした書き込みを、要求ごと 400 で断り、料理を消さないこと")
        func rejectsUppercasedWrite() async throws {
            let (response, _) = try await server.send(
                uppercasedWriteRequest, body: HTTPBody(uppercasedWriteBody), baseURL: baseURL,
                operationID: Operations.PushSyncWrites.id)
            let pulled = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())

            #expect(response.status == .badRequest)
            #expect(pulled == FakeSyncServerTests.page([.dish(dish)], next: 1))
        }

        @Test("大文字の端末の ID で取りに行く要求を、400 で断ること")
        func rejectsUppercasedDeviceId() async throws {
            let (response, _) = try await server.send(
                uppercasedPullRequest, body: nil, baseURL: baseURL,
                operationID: Operations.PullSyncChanges.id)

            #expect(response.status == .badRequest)
        }
    }
}
