#if DEBUG
    import Foundation
    import HTTPTypes
    import OpenAPIRuntime

    /// サインインとアカウントの削除だけに答える。UI テストはサーバーにつながない
    nonisolated struct StubAPITransport: ClientTransport {
        let behavior: Behavior

        @concurrent func send(
            _ request: HTTPRequest,
            body: HTTPBody?,
            baseURL: URL,
            operationID: String
        ) async throws -> (HTTPResponse, HTTPBody?) {
            switch behavior {
            case .offline:
                throw URLError(.notConnectedToInternet)
            case .online, .rateLimited, .unauthorized, .serverError:
                switch operationID {
                case "createSession":
                    return createdSession
                case "deleteAccount":
                    return deleteAccountResponse
                default:
                    return (HTTPResponse(status: .notFound), nil)
                }
            }
        }

        enum Behavior {
            case online
            case offline
            case rateLimited
            case unauthorized
            case serverError
        }

        private var createdSession: (HTTPResponse, HTTPBody?) {
            var response = HTTPResponse(status: .created)
            response.headerFields[.contentType] = "application/json"
            return (
                response,
                HTTPBody(#"{"sessionToken":"stub-session","accountId":"stub-account"}"#)
            )
        }

        private var deleteAccountResponse: (HTTPResponse, HTTPBody?) {
            let status: HTTPResponse.Status =
                switch behavior {
                case .online, .offline: .noContent
                case .rateLimited: .tooManyRequests
                case .unauthorized: .unauthorized
                case .serverError: .internalServerError
                }
            return (HTTPResponse(status: status), nil)
        }
    }
#endif
