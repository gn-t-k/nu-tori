#if DEBUG
    import Foundation
    import HTTPTypes
    import NuToriCore
    import OpenAPIRuntime

    /// サインインと、記録の取得・送信だけに答える。UI テストはサーバーにつながらない
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
            case .hangPull:
                if request.path == "/v1/sessions" {
                    return createdSession()
                }
                // テストが見ているあいだ、初回の取得を終えない
                try await Task.sleep(for: .seconds(60))
                throw URLError(.timedOut)
            case .online, .weightRecords:
                // 取得の path にはクエリが付く
                switch request.path {
                case "/v1/sessions":
                    return createdSession()
                case "/v1/sync/writes":
                    return json(.ok, #"{"results":[]}"#)
                case .some(let path) where path.hasPrefix("/v1/sync/changes"):
                    return json(
                        .ok,
                        behavior == .weightRecords ? try weightRecordsBody() : emptyChangesBody()
                    )
                default:
                    return (HTTPResponse(status: .notFound), nil)
                }
            }
        }

        enum Behavior {
            case online
            case offline
            case weightRecords
            case hangPull
        }

        private func createdSession() -> (HTTPResponse, HTTPBody?) {
            json(.created, #"{"sessionToken":"stub-session","accountId":"stub-account"}"#)
        }

        private func emptyChangesBody() -> String {
            let startedOn = TimelineDayText.startedOn(
                for: CalendarDay(containing: .now, in: .current))
            return
                #"{"changes":[],"hasMore":false,"nextAfterSequence":0,"startedOn":"\#(startedOn)"}"#
        }

        private func weightRecordsBody() throws -> String {
            let zone = TimeZone.current.identifier
            let startedOn = TimelineDayText.startedOn(
                for: CalendarDay(containing: .now, in: .current))
            let manualAt = try milliseconds(dayOffset: 0, hour: 7, minute: 12)
            let importedAt = try milliseconds(dayOffset: 1, hour: 8, minute: 0)
            return """
                {"changes":[\
                {"sequence":1,"kind":"weight_record","recordId":"11111111-1111-4111-8111-111111111111",\
                "record":{"id":"11111111-1111-4111-8111-111111111111","weightKg":72.4,\
                "measuredAt":\(manualAt),"timeZone":"\(zone)","version":1}},\
                {"sequence":2,"kind":"weight_record","recordId":"22222222-2222-4222-8222-222222222222",\
                "record":{"id":"22222222-2222-4222-8222-222222222222","weightKg":71.8,\
                "measuredAt":\(importedAt),"timeZone":"\(zone)","version":1,\
                "imported":{"sourceAppName":"Withings","sourceBundleId":"com.withings.wiScaleNG",\
                "healthkitSampleUuid":"33333333-3333-4333-8333-333333333333"}}}\
                ],"hasMore":false,"nextAfterSequence":2,"startedOn":"\(startedOn)"}
                """
        }

        private func milliseconds(dayOffset: Int, hour: Int, minute: Int) throws -> Int {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let start = calendar.startOfDay(for: .now)
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start),
                let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else {
                throw URLError(.cannotParseResponse)
            }
            return Int((date.timeIntervalSince1970 * 1000).rounded())
        }

        private func json(_ status: HTTPResponse.Status, _ body: String) -> (
            HTTPResponse, HTTPBody?
        ) {
            var response = HTTPResponse(status: status)
            response.headerFields[.contentType] = "application/json"
            return (response, HTTPBody(body))
        }
    }
#endif
