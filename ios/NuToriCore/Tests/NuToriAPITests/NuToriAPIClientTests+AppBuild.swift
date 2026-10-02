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
                    appBuild: 42,
                    sessionToken: { "session-1" },
                    appBuildVerdict: { _ in }
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
            let verdicts: VerdictLog
            let client: NuToriAPIClient

            init() {
                let verdicts = VerdictLog()
                self.verdicts = verdicts
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        status: HTTPResponse.Status(code: 426),
                        json: #"{"code":"app_build_unsupported"}"#),
                    appBuild: 41,
                    sessionToken: { "session-1" },
                    appBuildVerdict: { verdicts.append($0) }
                )
            }

            @Test("同期の取得が、締め出しのエラーを投げること")
            func pullThrows() async {
                await #expect {
                    _ = try await client.pullSyncChanges(
                        afterSequence: 0, clientState: .fixture())
                } throws: {
                    $0.isAppBuildUnsupported
                }
            }

            @Test("サインインが、締め出しのエラーを投げること")
            func startSessionThrows() async {
                await #expect {
                    _ = try await client.startSession(
                        idToken: "id-token", nonce: "nonce", authorizationCode: "code",
                        timeZone: TimeZone(identifier: "Asia/Tokyo")!)
                } throws: {
                    $0.isAppBuildUnsupported
                }
            }

            @Test("アカウントの削除が、締め出しのエラーを投げること")
            func deleteAccountThrows() async {
                await #expect {
                    _ = try await client.deleteAccount()
                } throws: {
                    $0.isAppBuildUnsupported
                }
            }

            @Test("締め出されたと知らせること")
            func reportsUnsupported() async {
                _ = try? await client.deleteAccount()

                #expect(verdicts.values == [.unsupported])
            }
        }

        @Suite("サーバーが 426 でない応答を返したとき")
        struct Supported {
            let verdicts: VerdictLog
            let client: NuToriAPIClient

            init() {
                let verdicts = VerdictLog()
                self.verdicts = verdicts
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .unauthorized),
                    appBuild: 42,
                    sessionToken: { "session-1" },
                    appBuildVerdict: { verdicts.append($0) }
                )
            }

            @Test("受け付けられたと知らせること")
            func reportsSupported() async throws {
                _ = try await client.deleteAccount()

                #expect(verdicts.values == [.supported])
            }
        }

        @Suite("要求が届かなかったとき")
        struct Unreachable {
            let verdicts: VerdictLog
            let client: NuToriAPIClient

            init() {
                let verdicts = VerdictLog()
                self.verdicts = verdicts
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.error(URLError(.notConnectedToInternet)),
                    appBuild: 42,
                    sessionToken: { "session-1" },
                    appBuildVerdict: { verdicts.append($0) }
                )
            }

            @Test("何も知らせないこと")
            func reportsNothing() async {
                _ = try? await client.deleteAccount()

                #expect(verdicts.values.isEmpty)
            }
        }
    }

    final class VerdictLog: @unchecked Sendable {
        private(set) var values: [AppBuildVerdict] = []

        func append(_ verdict: AppBuildVerdict) {
            values.append(verdict)
        }
    }
}
