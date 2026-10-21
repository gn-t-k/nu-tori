public import Foundation

extension NuToriAPIClient {
    /// 今の規約の版に、同意が要るかを問う
    public func termsAgreementRequirement() async throws -> TermsAgreementRequirementResult {
        switch try await client.getTermsAgreementRequirement() {
        case .ok(let ok):
            let body = try ok.body.json
            return body.agreementRequired
                ? .required(termsVersion: body.termsVersion) : .notRequired
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// 同意のシートで、規約の版に同意する。同じ `requestId` で送り直しても、同意は1つだけ残る
    public func agreeToTerms(requestId: UUID, termsVersion: String) async throws
        -> AgreeToTermsResult
    {
        let output = try await client.agreeToTerms(
            body: .json(.init(requestId: requestId.canonicalString, termsVersion: termsVersion)))
        switch output {
        case .noContent:
            return .agreed
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .sessionExpired
        case .unprocessableContent:
            return .unknownTermsVersion
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    public enum TermsAgreementRequirementResult: Sendable, Equatable {
        case required(termsVersion: String)
        case notRequired
        case sessionExpired
        case rateLimited
    }

    public enum AgreeToTermsResult: Sendable, Equatable {
        case agreed
        case badRequest
        case sessionExpired
        /// サーバーが知らない版。端末とサーバーの版がずれた不具合のときだけ
        case unknownTermsVersion
        case rateLimited
    }
}
