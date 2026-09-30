#if DEBUG
    import Foundation
    import HTTPTypes
    import OpenAPIRuntime

    /// サインインの経路だけに答える。UI テストが使う経路は、ほかに無い
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
            case .online:
                guard request.path == "/v1/sessions" else {
                    return (HTTPResponse(status: .notFound), nil)
                }
                var response = HTTPResponse(status: .created)
                response.headerFields[.contentType] = "application/json"
                return (
                    response,
                    HTTPBody(#"{"sessionToken":"stub-session","accountId":"stub-account"}"#)
                )
            }
        }

        enum Behavior {
            case online
            case offline
        }
    }
#endif
