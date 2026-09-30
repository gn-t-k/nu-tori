#if DEBUG
    import Foundation
    import HTTPTypes
    import NuToriCore
    import OpenAPIRuntime

    /// サインイン、記録の取得・送信、アカウントの削除だけに答える。UI テストはサーバーにつながらない
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
            case .online, .weightRecords, .dayRing, .accountDeletionRateLimited,
                .accountDeletionUnauthorized:
                // 取得の path にはクエリが付く
                switch request.path {
                case "/v1/sessions":
                    return createdSession()
                case "/v1/account":
                    return deleteAccountResponse()
                case "/v1/sync/writes":
                    return json(.ok, #"{"results":[]}"#)
                case .some(let path) where path.hasPrefix("/v1/sync/changes"):
                    return json(.ok, try changesBody())
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
            case .weightScreen, .weightScreenPushRejected:
                switch request.path {
                case "/v1/sessions":
                    return createdSession()
                case "/v1/sync/writes":
                    return json(.ok, try await weightScreenPushResults(body))
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
            case dayRing
            case hangPull
            /// 昨日の体重だけを返し、今日は未記録にする
            case previousDay
            case previousDayPushOffline
            case previousDayPushRejected
            case weightScreen
            /// 直す書き込みを受け付けず、サーバーの今の値（直す前の記録）を添える
            case weightScreenPushRejected
            /// アカウントの削除だけに 429 を返す
            case accountDeletionRateLimited
            /// アカウントの削除だけに 401 を返す
            case accountDeletionUnauthorized
        }

        private func deleteAccountResponse() -> (HTTPResponse, HTTPBody?) {
            let status: HTTPResponse.Status =
                switch behavior {
                case .accountDeletionRateLimited: .tooManyRequests
                case .accountDeletionUnauthorized: .unauthorized
                case .online, .offline, .weightRecords, .dayRing, .hangPull, .previousDay,
                    .previousDayPushOffline, .previousDayPushRejected, .weightScreen,
                    .weightScreenPushRejected:
                    .noContent
                }
            return (HTTPResponse(status: status), nil)
        }

        private func pushResponse(_ body: HTTPBody?) async throws -> (HTTPResponse, HTTPBody?) {
            switch behavior {
            case .previousDayPushOffline:
                throw URLError(.notConnectedToInternet)
            case .previousDayPushRejected:
                // サーバーにその記録は無い（作る書き込みが受け付けられなかった）
                return json(
                    .ok,
                    try await writeResults(
                        from: body, result: .rejected(current: #"{"status":"absent"}"#)))
            case .online, .offline, .weightRecords, .dayRing, .hangPull, .previousDay,
                .weightScreen, .weightScreenPushRejected, .accountDeletionRateLimited,
                .accountDeletionUnauthorized:
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

        private func weightScreenPushResults(_ body: HTTPBody?) async throws -> String {
            switch behavior {
            case .weightScreenPushRejected:
                let current =
                    #"{"status":"value","change":{"kind":"weight_record","recordId":"\#(Self.weightScreenRecordId)","record":\#(try weightScreenRecord())}}"#
                return try await writeResults(from: body, result: .rejected(current: current))
            case .online, .offline, .weightRecords, .dayRing, .hangPull, .previousDay,
                .previousDayPushOffline, .previousDayPushRejected, .weightScreen,
                .accountDeletionRateLimited, .accountDeletionUnauthorized:
                return try await applyWeightScreenPush(body)
            }
        }

        private func weightScreenBody() throws -> String {
            let startedOn = TimelineDayText.startedOn(
                for: CalendarDay(containing: .now, in: .current))
            return """
                {"changes":[{"sequence":1,"kind":"weight_record",\
                "recordId":"\(Self.weightScreenRecordId)","record":\(try weightScreenRecord())}],\
                "hasMore":false,"nextAfterSequence":1,"startedOn":"\(startedOn)"}
                """
        }

        private static let weightScreenRecordId = "11111111-1111-4111-8111-111111111111"

        private func weightScreenRecord() throws -> String {
            let zone = TimeZone.current.identifier
            let measuredAt = try milliseconds(dayOffset: 0, hour: 7, minute: 12)
            let kilograms = weightScreenKilograms.current()
            return """
                {"id":"\(Self.weightScreenRecordId)","weightKg":\(kilograms),\
                "measuredAt":\(measuredAt),"timeZone":"\(zone)","version":1}
                """
        }

        private enum WriteResult {
            case applied
            /// current は、断った記録のサーバーの今の値（`SyncWriteCurrent` の JSON）
            case rejected(current: String)
        }

        private func writeResults(from body: HTTPBody?, result: WriteResult) async throws -> String
        {
            let ids = try await writeIds(in: body)
            let results = ids.map { id in
                switch result {
                case .applied:
                    #"{"writeId":"\#(id)","result":"applied"}"#
                case .rejected(let current):
                    // 理由は画面の文言に出ないので、1つに決める
                    #"{"writeId":"\#(id)","result":"rejected","rejectionReason":"out_of_range","current":\#(current)}"#
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

        private func changesBody() throws -> String {
            switch behavior {
            case .weightRecords: return try weightRecordsBody()
            case .dayRing: return try dayRingBody()
            case .online, .offline, .hangPull, .previousDay, .previousDayPushOffline,
                .previousDayPushRejected, .weightScreen, .weightScreenPushRejected,
                .accountDeletionRateLimited, .accountDeletionUnauthorized:
                return emptyChangesBody()
            }
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

        /// 使い始めた日を3週間前にし、その日に記録を2件置く。帯を週単位で送って、画面の外の日へ移れる
        private func dayRingBody() throws -> String {
            let zone = TimeZone.current.identifier
            let startedOn = TimelineDayText.startedOn(
                for: CalendarDay(containing: .now, in: .current).advanced(by: -21))
            let early = try milliseconds(dayOffset: -21, hour: 6, minute: 0)
            let late = try milliseconds(dayOffset: -21, hour: 21, minute: 0)
            let manualAt = try milliseconds(dayOffset: 0, hour: 7, minute: 12)
            let importedAt = try milliseconds(dayOffset: 1, hour: 8, minute: 0)
            let withings =
                #"{"sourceAppName":"Withings","sourceBundleId":"com.withings.wiScaleNG","healthkitSampleUuid":"33333333-3333-4333-8333-333333333333"}"#
            let changes = [
                weightChange(
                    sequence: 1, id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1", kilograms: 70.0,
                    at: early, zone: zone, imported: nil),
                weightChange(
                    sequence: 2, id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2", kilograms: 70.5,
                    at: late, zone: zone, imported: nil),
                weightChange(
                    sequence: 3, id: "11111111-1111-4111-8111-111111111111", kilograms: 72.4,
                    at: manualAt, zone: zone, imported: nil),
                weightChange(
                    sequence: 4, id: "22222222-2222-4222-8222-222222222222", kilograms: 71.8,
                    at: importedAt, zone: zone, imported: withings),
            ]
            return
                #"{"changes":[\#(changes.joined(separator: ","))],"hasMore":false,"nextAfterSequence":4,"startedOn":"\#(startedOn)"}"#
        }

        private func weightChange(
            sequence: Int, id: String, kilograms: Double, at milliseconds: Int, zone: String,
            imported: String?
        ) -> String {
            let importedField = imported.map { #","imported":\#($0)"# } ?? ""
            return """
                {"sequence":\(sequence),"kind":"weight_record","recordId":"\(id)",\
                "record":{"id":"\(id)","weightKg":\(kilograms),\
                "measuredAt":\(milliseconds),"timeZone":"\(zone)","version":1\(importedField)}}
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
