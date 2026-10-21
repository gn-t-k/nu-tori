public import Foundation
public import NuToriAPI

/// すでにサインインしている人から、規約への同意を取る。同意は同期の外の要求で、送り待ちの箱を通さない
public actor TermsAgreementPrompt {
    public init(
        client: NuToriAPIClient,
        analytics: any AnalyticsSession,
        newRequestId: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.client = client
        self.analytics = analytics
        self.newRequestId = newRequestId
    }

    /// 開いたとき（前面に来たとき）に、同意が要るかを問う。要れば出すシートを返す。
    /// 要らないとき、電波が無いときやサーバーが答えられないときは nil を返し、次に開いたときに問い直す
    public func sheetOnOpen() async -> TermsAgreementSheet? {
        guard
            case .required(let termsVersion) = try? await client.termsAgreementRequirement()
        else { return nil }
        await analytics.capture(.termsAgreementSheetShown)
        return TermsAgreementSheet(termsVersion: termsVersion)
    }

    /// 「同意して続ける」を押した。その場の要求で同意を送る。
    /// 送れずに押し直したときは、同じ要求の ID で送り、サーバーに同意を2つ残さない
    public func agree(to sheet: TermsAgreementSheet) async -> AgreeOutcome {
        let requestId = requestIds[sheet.termsVersion] ?? newRequestId()
        requestIds[sheet.termsVersion] = requestId
        let result: NuToriAPIClient.AgreeToTermsResult
        do {
            result = try await client.agreeToTerms(
                requestId: requestId, termsVersion: sheet.termsVersion)
        } catch {
            return .notAgreed(error.isUnreachableOrTimedOut ? .unreachable : .retryLater)
        }
        switch result {
        case .agreed:
            await analytics.capture(.termsAgreed)
            return .agreed
        // セッションが切れたときは、同時に回る同期がサインインの画面に替え、シートも消える
        case .badRequest, .sessionExpired, .unknownTermsVersion, .rateLimited:
            return .notAgreed(.retryLater)
        }
    }

    public enum AgreeOutcome: Sendable, Equatable {
        /// 受け付けられた。シートを閉じる
        case agreed
        /// 受け付けられなかった。シートを出したまま、押し直してもらう
        case notAgreed(FailureReason)

        public enum FailureReason: Sendable, Equatable {
            /// 電波が無いときと時間切れ
            case unreachable
            /// 回数の歯止めとサーバーの失敗
            case retryLater
        }
    }

    private let client: NuToriAPIClient
    private let analytics: any AnalyticsSession
    private let newRequestId: @Sendable () -> UUID
    /// 版ごとの、送った同意の要求の ID
    private var requestIds: [String: UUID] = [:]
}
