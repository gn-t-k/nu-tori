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
        @Test("同意が要れば、シートに出す版を返し、シートを出したことを PostHog に送ること")
        func showsSheetWhenRequired() async {
            let analytics = AnalyticsSessionMock.ok()
            let prompt = TermsAgreementPrompt.fixture(
                transport: .termsAgreement(agreementRequired: true, termsVersion: "1"),
                analytics: analytics)

            let sheet = await prompt.sheetOnOpen()

            #expect(sheet == TermsAgreementSheet(termsVersion: "1"))
            #expect(analytics.captured == [.termsAgreementSheetShown])
        }

        @Test("同意が要らなければ、シートを出さず、PostHog にも送らないこと")
        func hidesSheetWhenNotRequired() async {
            let analytics = AnalyticsSessionMock.ok()
            let prompt = TermsAgreementPrompt.fixture(
                transport: .termsAgreement(agreementRequired: false, termsVersion: "1"),
                analytics: analytics)

            let sheet = await prompt.sheetOnOpen()

            #expect(sheet == nil)
            #expect(analytics.captured.isEmpty)
        }

        @Test("電波が無ければ、シートを出さないこと")
        func hidesSheetWhenUnreachable() async {
            let analytics = AnalyticsSessionMock.ok()
            let prompt = TermsAgreementPrompt.fixture(
                transport: .error(URLError(.notConnectedToInternet)), analytics: analytics)

            let sheet = await prompt.sheetOnOpen()

            #expect(sheet == nil)
            #expect(analytics.captured.isEmpty)
        }

        @Test("サーバーが答えられなければ、シートを出さないこと")
        func hidesSheetWhenServerFails() async {
            let prompt = TermsAgreementPrompt.fixture(
                transport: .ok(status: .internalServerError))

            let sheet = await prompt.sheetOnOpen()

            #expect(sheet == nil)
        }

        @Test("電波が無くて出さなかったあと、次に開いたときに問い直してシートを出すこと")
        func asksAgainOnNextOpen() async {
            let reachability = Reachability()
            let prompt = TermsAgreementPrompt.fixture(
                transport: .termsAgreement(
                    agreementRequired: true, termsVersion: "1",
                    reachable: { reachability.isReachable }))

            let offline = await prompt.sheetOnOpen()
            reachability.isReachable = true
            let online = await prompt.sheetOnOpen()

            #expect(offline == nil)
            #expect(online == TermsAgreementSheet(termsVersion: "1"))
        }
    }

    @Suite("同意して続けるを押したとき")
    struct Agreeing {
        @Test("送り待ちを通さず、その場の要求でシートの版への同意を送ること")
        func sendsAgreementRightAway() async throws {
            let requestId = UUID(uuidString: "6A1F2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D")!
            let transport = ClientTransportMock.termsAgreement(
                agreementRequired: true, termsVersion: "1")
            let prompt = TermsAgreementPrompt.fixture(
                transport: transport, newRequestId: { requestId })

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

        @Test("受け付けられたら、同意したことを PostHog に送ること")
        func capturesAgreement() async {
            let analytics = AnalyticsSessionMock.ok()
            let prompt = TermsAgreementPrompt.fixture(
                transport: .termsAgreement(agreementRequired: true, termsVersion: "1"),
                analytics: analytics)

            _ = await prompt.agree(to: TermsAgreementSheet(termsVersion: "1"))

            #expect(analytics.captured == [.termsAgreed])
        }

        @Test("電波が無ければ、つながらなかったと返し、PostHog に送らないこと")
        func reportsUnreachable() async {
            let analytics = AnalyticsSessionMock.ok()
            let prompt = TermsAgreementPrompt.fixture(
                transport: .error(URLError(.notConnectedToInternet)), analytics: analytics)

            let outcome = await prompt.agree(to: TermsAgreementSheet(termsVersion: "1"))

            #expect(outcome == .notAgreed(.unreachable))
            #expect(analytics.captured.isEmpty)
        }

        @Test("サーバーが受け付けなければ、あとでやり直すよう返すこと")
        func reportsRetryLater() async {
            let prompt = TermsAgreementPrompt.fixture(
                transport: .termsAgreement(
                    agreementRequired: true, termsVersion: "1", agreeStatus: .tooManyRequests))

            let outcome = await prompt.agree(to: TermsAgreementSheet(termsVersion: "1"))

            #expect(outcome == .notAgreed(.retryLater))
        }

        @Test("送れずに押し直したときは、同じ要求の ID で送り直すこと")
        func resendsWithSameRequestId() async throws {
            let transport = ClientTransportMock.error(URLError(.notConnectedToInternet))
            let prompt = TermsAgreementPrompt.fixture(transport: transport)
            let sheet = TermsAgreementSheet(termsVersion: "1")

            _ = await prompt.agree(to: sheet)
            _ = await prompt.agree(to: sheet)

            let requestIds = try transport.requests.map {
                try JSONDecoder().decode(
                    [String: String].self, from: Data(try #require($0.body).utf8))["requestId"]
            }
            #expect(requestIds.count == 2)
            #expect(requestIds[0] != nil)
            #expect(requestIds[0] == requestIds[1])
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

/// 問い直すあいだに、電波が戻ったことにする
private final class Reachability: @unchecked Sendable {
    var isReachable = false
}
