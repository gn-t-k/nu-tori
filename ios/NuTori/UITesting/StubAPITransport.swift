#if DEBUG
    import Foundation
    import HTTPTypes
    import NuToriCore
    import OpenAPIRuntime

    /// サインインと、記録の取得・送信だけに答える。UI テストはサーバーにつながらない
    nonisolated struct StubAPITransport: ClientTransport {
        let behavior: Behavior
        private let weightScreenKilograms = WeightScreenKilograms()

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
            case .previousDay, .previousDayPushOffline, .previousDayPushRejected:
                switch request.path {
                case "/v1/sessions":
                    return createdSession()
                case "/v1/sync/writes":
                    return try await pushResponse(body)
                case .some(let path) where path.hasPrefix("/v1/sync/changes"):
                    return json(.ok, try previousDayBody())
                default:
                    return (HTTPResponse(status: .notFound), nil)
                }
            case .weightScreen:
                switch request.path {
                case "/v1/sessions":
                    return createdSession()
                case "/v1/sync/writes":
                    return json(.ok, try await applyWeightScreenPush(body))
                case .some(let path) where path.hasPrefix("/v1/sync/changes"):
                    return json(.ok, try weightScreenBody())
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
            /// 昨日の体重だけを返し、今日は未記録にする
            case previousDay
            case previousDayPushOffline
            case previousDayPushRejected
            case weightScreen
        }

        private func pushResponse(_ body: HTTPBody?) async throws -> (HTTPResponse, HTTPBody?) {
            switch behavior {
            case .previousDayPushOffline:
                throw URLError(.notConnectedToInternet)
            case .previousDayPushRejected:
                return json(.ok, try await writeResults(from: body, result: .rejected))
            case .online, .offline, .weightRecords, .hangPull, .previousDay, .weightScreen:
                return json(.ok, try await writeResults(from: body, result: .applied))
            }
        }

        private func applyWeightScreenPush(_ body: HTTPBody?) async throws -> String {
            guard let body else { return #"{"results":[]}"# }
            let bytes = try await [UInt8](collecting: body, upTo: 1_048_576)
            let decoded = try JSONDecoder().decode(WeightScreenPush.self, from: Data(bytes))
            if let kilograms = decoded.writes.first(where: { $0.type == "update_weight_record" })?
                .weightRecord?.weightKg
            {
                weightScreenKilograms.replace(with: kilograms)
            }
            let results = decoded.writes.map { #"{"writeId":"\#($0.id)","result":"applied"}"# }
            return #"{"results":[\#(results.joined(separator: ","))]}"#
        }

        private func weightScreenBody() throws -> String {
            let zone = TimeZone.current.identifier
            let startedOn = TimelineDayText.startedOn(
                for: CalendarDay(containing: .now, in: .current))
            let measuredAt = try milliseconds(dayOffset: 0, hour: 7, minute: 12)
            let kilograms = weightScreenKilograms.current()
            return """
                {"changes":[{"sequence":1,"kind":"weight_record",\
                "recordId":"11111111-1111-4111-8111-111111111111",\
                "record":{"id":"11111111-1111-4111-8111-111111111111","weightKg":\(kilograms),\
                "measuredAt":\(measuredAt),"timeZone":"\(zone)","version":1}}],\
                "hasMore":false,"nextAfterSequence":1,"startedOn":"\(startedOn)"}
                """
        }

        private enum WriteResult {
            case applied
            case rejected
        }

        private func writeResults(from body: HTTPBody?, result: WriteResult) async throws -> String
        {
            let ids = try await writeIds(in: body)
            let results = ids.map { id in
                switch result {
                case .applied:
                    #"{"writeId":"\#(id)","result":"applied"}"#
                case .rejected:
                    #"{"writeId":"\#(id)","result":"rejected","rejectionReason":"out_of_range"}"#
                }
            }
            return #"{"results":[\#(results.joined(separator: ","))]}"#
        }

        private func writeIds(in body: HTTPBody?) async throws -> [String] {
            guard let body else { return [] }
            let bytes = try await [UInt8](collecting: body, upTo: 1_048_576)
            let decoded = try JSONDecoder().decode(PushBody.self, from: Data(bytes))
            return decoded.writes.map(\.id)
        }

        private final class WeightScreenKilograms: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 72.4

            func current() -> Double {
                lock.lock()
                defer { lock.unlock() }
                return value
            }

            func replace(with kilograms: Double) {
                lock.lock()
                defer { lock.unlock() }
                value = kilograms
            }
        }

        private struct WeightScreenPush: Decodable {
            let writes: [Write]

            struct Write: Decodable {
                let id: String
                let type: String
                let weightRecord: Weight?

                struct Weight: Decodable {
                    let weightKg: Double
                }
            }
        }

        private struct PushBody: Decodable {
            let writes: [Write]

            struct Write: Decodable {
                let id: String
            }
        }

        private func createdSession() -> (HTTPResponse, HTTPBody?) {
            json(.created, #"{"sessionToken":"stub-session","accountId":"stub-account"}"#)
        }

        private func previousDayBody() throws -> String {
            let zone = TimeZone.current.identifier
            let yesterday = CalendarDay(containing: .now, in: .current).advanced(by: -1)
            let startedOn = TimelineDayText.startedOn(for: yesterday)
            let measuredAt = try milliseconds(dayOffset: -1, hour: 7, minute: 12)
            return """
                {"changes":[{"sequence":1,"kind":"weight_record",\
                "recordId":"44444444-4444-4444-8444-444444444444",\
                "record":{"id":"44444444-4444-4444-8444-444444444444","weightKg":72.6,\
                "measuredAt":\(measuredAt),"timeZone":"\(zone)","version":1}}],\
                "hasMore":false,"nextAfterSequence":1,"startedOn":"\(startedOn)"}
                """
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
