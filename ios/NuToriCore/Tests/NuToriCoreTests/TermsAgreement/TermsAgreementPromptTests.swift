import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("規約への同意のシート")
struct TermsAgreementPromptTests {
    @Suite("開いたとき")
    struct OnOpen {
        @Suite("同意が要るとき")
        struct AgreementRequired {
            let analytics: AnalyticsSessionMock
            let prompt: TermsAgreementPrompt

            init() {
                analytics = .ok()
                prompt = .fixture(
                    transport: .termsAgreement(agreementRequired: true, termsVersion: "1"),
                    analytics: analytics)
            }

            @Test("シートに出す版を返し、出す前には PostHog に送らないこと")
            func showsSheetWhenRequired() async {
                let sheet = await prompt.sheetOnOpen()

                #expect(sheet == TermsAgreementSheet(termsVersion: "1"))
                #expect(analytics.captured.isEmpty)
            }
        }

        @Suite("同意が要らないとき")
        struct AgreementNotRequired {
            let analytics: AnalyticsSessionMock
            let prompt: TermsAgreementPrompt

            init() {
                analytics = .ok()
                prompt = .fixture(
                    transport: .termsAgreement(agreementRequired: false, termsVersion: "1"),
                    analytics: analytics)
            }

            @Test("シートを出さず、PostHog にも送らないこと")
            func hidesSheetWhenNotRequired() async {
                let sheet = await prompt.sheetOnOpen()

                #expect(sheet == nil)
                #expect(analytics.captured.isEmpty)
            }
        }

        @Suite("電波が無いとき")
        struct Unreachable {
            let analytics: AnalyticsSessionMock
            let prompt: TermsAgreementPrompt

            init() {
                analytics = .ok()
                prompt = .fixture(
                    transport: .error(URLError(.notConnectedToInternet)), analytics: analytics)
            }

            @Test("シートを出さないこと")
            func hidesSheetWhenUnreachable() async {
                let sheet = await prompt.sheetOnOpen()

                #expect(sheet == nil)
                #expect(analytics.captured.isEmpty)
            }
        }

        @Suite("サーバーが答えられないとき")
        struct ServerFailed {
            let prompt: TermsAgreementPrompt

            init() {
                prompt = .fixture(transport: .ok(status: .internalServerError))
            }

            @Test("シートを出さないこと")
            func hidesSheetWhenServerFails() async {
                let sheet = await prompt.sheetOnOpen()

                #expect(sheet == nil)
            }
        }

        @Suite("電波が無くて出さなかったあと、電波が戻ったとき")
        struct ReachableAgain {
            let prompt: TermsAgreementPrompt
            let offline: TermsAgreementSheet?

            init() async {
                let reachability = ReachabilitySwitch(isReachable: false)
                prompt = .fixture(
                    transport: .termsAgreement(
                        agreementRequired: true, termsVersion: "1",
                        reachable: { reachability.isReachable }))
                offline = await prompt.sheetOnOpen()
                reachability.isReachable = true
            }

            @Test("次に開いたときに問い直してシートを出すこと")
            func asksAgainOnNextOpen() async {
                let online = await prompt.sheetOnOpen()

                #expect(offline == nil)
                #expect(online == TermsAgreementSheet(termsVersion: "1"))
            }
        }
    }

    @Suite("シートを出したとき")
    struct Presented {
        let analytics: AnalyticsSessionMock
        let prompt: TermsAgreementPrompt

        init() {
            analytics = .ok()
            prompt = .fixture(
                transport: .termsAgreement(agreementRequired: true, termsVersion: "1"),
                analytics: analytics)
        }

        @Test("シートを出したことを PostHog に送ること")
        func capturesSheetShown() async {
            await prompt.sheetPresented()

            #expect(analytics.captured == [.termsAgreementSheetShown])
        }
    }

    @Suite("同意して続けるを押したとき")
    struct Agreeing {
        @Suite("受け付けられたとき")
        struct Accepted {
            let transport: ClientTransportMock
            let analytics: AnalyticsSessionMock
            let prompt: TermsAgreementPrompt

            init() {
                let requestId = UUID(uuidString: "6A1F2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D")!
                transport = .termsAgreement(agreementRequired: true, termsVersion: "1")
                analytics = .ok()
                prompt = .fixture(
                    transport: transport, analytics: analytics, newRequestId: { requestId })
            }

            @Test("送り待ちを通さず、その場の要求でシートの版への同意を送ること")
            func sendsAgreementRightAway() async throws {
                let outcome = await prompt.agree(to: TermsAgreementSheet(termsVersion: "1"))

                #expect(outcome == .agreed)
                let sent = try #require(transport.requests.last)
                #expect(sent.request.method == .post)
                #expect(sent.request.path == "/v1/terms-agreements")
                let body = try JSONDecoder().decode(
                    [String: String].self, from: Data(try #require(sent.body).utf8))
                #expect(
                    body == [
                        "requestId": "6a1f2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", "termsVersion": "1",
                    ])
            }

            @Test("同意したことを PostHog に送ること")
            func capturesAgreement() async {
                _ = await prompt.agree(to: TermsAgreementSheet(termsVersion: "1"))

                #expect(analytics.captured == [.termsAgreed])
            }
        }

        @Suite("電波が無いとき")
        struct Unreachable {
            let analytics: AnalyticsSessionMock
            let prompt: TermsAgreementPrompt

            init() {
                analytics = .ok()
                prompt = .fixture(
                    transport: .error(URLError(.notConnectedToInternet)), analytics: analytics)
            }

            @Test("つながらなかったと返し、PostHog に送らないこと")
            func reportsUnreachable() async {
                let outcome = await prompt.agree(to: TermsAgreementSheet(termsVersion: "1"))

                #expect(outcome == .notAgreed(.unreachable))
                #expect(analytics.captured.isEmpty)
            }
        }

        @Suite("サーバーが受け付けないとき")
        struct Rejected {
            let prompt: TermsAgreementPrompt

            init() {
                prompt = .fixture(
                    transport: .termsAgreement(
                        agreementRequired: true, termsVersion: "1", agreeStatus: .tooManyRequests))
            }

            @Test("あとでやり直すよう返すこと")
            func reportsRetryLater() async {
                let outcome = await prompt.agree(to: TermsAgreementSheet(termsVersion: "1"))

                #expect(outcome == .notAgreed(.retryLater))
            }
        }

        @Suite("送れずに押し直したとき")
        struct Retried {
            let transport: ClientTransportMock
            let prompt: TermsAgreementPrompt
            let sheet: TermsAgreementSheet

            init() async {
                transport = .error(URLError(.notConnectedToInternet))
                prompt = .fixture(transport: transport)
                sheet = TermsAgreementSheet(termsVersion: "1")
                _ = await prompt.agree(to: sheet)
            }

            @Test("同じ要求の ID で送り直すこと")
            func resendsWithSameRequestId() async throws {
                _ = await prompt.agree(to: sheet)

                let requestIds = try transport.requests.map {
                    try JSONDecoder().decode(
                        [String: String].self, from: Data(try #require($0.body).utf8))["requestId"]
                }
                try #require(requestIds.count == 2)
                #expect(requestIds[0] != nil)
                #expect(requestIds[0] == requestIds[1])
            }
        }
    }
}

extension TermsAgreementPrompt {
    fileprivate static func fixture(
        transport: ClientTransportMock,
        analytics: AnalyticsSessionMock = .ok(),
        newRequestId: @escaping @Sendable () -> UUID = { UUID() }
    ) -> TermsAgreementPrompt {
        TermsAgreementPrompt(
            client: NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            ),
            analytics: analytics,
            newRequestId: newRequestId
        )
    }
}
