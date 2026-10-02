import Foundation
import HTTPTypes
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("ビルド番号")
    struct AppBuild {
        @Suite("要求を送るとき")
        struct Sending {
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
                transport = .sync()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    appBuildGate: AppBuildGateMock.ok(build: 42).gate,
                    sessionToken: { "session-1" }
                )
            }

            @Test("同期の取得に X-App-Build を付けること")
            func pullHasHeader() async throws {
                _ = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())

                let sent = try #require(transport.requests.first)
                #expect(sent.request.headerFields[HTTPField.Name("X-App-Build")!] == "42")
            }

            @Test("送り待ちの送信に X-App-Build を付けること")
            func pushHasHeader() async throws {
                _ = try await client.pushSyncWrites([], isFinalBatch: true, clientState: .fixture())

                let sent = try #require(transport.requests.first)
                #expect(sent.request.headerFields[HTTPField.Name("X-App-Build")!] == "42")
            }
        }

        @Suite("サーバーが 426 を返したとき")
        struct Unsupported {
            let gate: AppBuildGateMock
            let client: NuToriAPIClient

            init() {
                gate = .ok(build: 41)
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        status: HTTPResponse.Status(code: 426),
                        json: #"{"code":"app_build_unsupported"}"#),
                    appBuildGate: gate.gate,
                    sessionToken: { "session-1" }
                )
            }

            @Test("応答を解釈せずに、締め出しのエラーを投げること")
            func throwsUnsupported() async {
                await #expect {
                    _ = try await client.deleteAccount()
                } throws: {
                    $0.isAppBuildUnsupported
                }
            }

            @Test("締め出されたと知らせること")
            func reportsUnsupported() async {
                _ = try? await client.deleteAccount()

                #expect(gate.verdicts == [.unsupported])
            }
        }

        @Suite("サーバーが 426 でない応答を返したとき")
        struct Supported {
            let gate: AppBuildGateMock
            let client: NuToriAPIClient

            init() {
                gate = .ok(build: 42)
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .unauthorized),
                    appBuildGate: gate.gate,
                    sessionToken: { "session-1" }
                )
            }

            @Test("受け付けられたと知らせること")
            func reportsSupported() async throws {
                _ = try await client.deleteAccount()

                #expect(gate.verdicts == [.supported])
            }
        }

        @Suite("要求が届かなかったとき")
        struct Unreachable {
            let gate: AppBuildGateMock
            let client: NuToriAPIClient

            init() {
                gate = .ok(build: 42)
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.error(URLError(.notConnectedToInternet)),
                    appBuildGate: gate.gate,
                    sessionToken: { "session-1" }
                )
            }

            @Test("何も知らせないこと")
            func reportsNothing() async {
                _ = try? await client.deleteAccount()

                #expect(gate.verdicts.isEmpty)
            }
        }
    }
}
