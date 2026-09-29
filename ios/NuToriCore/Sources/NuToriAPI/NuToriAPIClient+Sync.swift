import Foundation
import OpenAPIRuntime

extension NuToriAPIClient {
    /// 1回の要求で送れるのは 500 件まで
    public func pushSyncWrites(
        _ writes: [SyncWrite],
        isFinalBatch: Bool,
        clientState: SyncClientState
    ) async throws -> PushSyncWritesResult {
        let output = try await client.pushSyncWrites(
            body: .json(
                .init(
                    clientState: .init(clientState),
                    writes: writes.map(Components.Schemas.SyncWrite.init),
                    isFinalBatch: isFinalBatch
                )
            )
        )
        switch output {
        case .ok(let ok):
            return .pushed(try ok.body.json.results.map(SyncWriteResult.init))
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// 最初は afterSequence を 0 にする
    public func pullSyncChanges(
        afterSequence: Int,
        clientState: SyncClientState
    ) async throws -> PullSyncChangesResult {
        let output = try await client.pullSyncChanges(
            query: .init(clientState, afterSequence: afterSequence)
        )
        switch output {
        case .ok(let ok):
            return .pulled(SyncChangesPage(try ok.body.json))
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    public enum PushSyncWritesResult: Sendable, Equatable {
        /// 送った書き込みと同じ順
        case pushed([SyncWriteResult])
        /// サーバーは何も当てていない
        case badRequest
        case sessionExpired
        case rateLimited
    }

    public enum PullSyncChangesResult: Sendable, Equatable {
        case pulled(SyncChangesPage)
        case badRequest
        case sessionExpired
        case rateLimited
    }

    public struct MalformedResponseError: Error, Equatable {
        public let reason: String
    }
}

extension Components.Schemas.SyncWrite {
    fileprivate init(_ write: SyncWrite) {
        switch write {
        case .createWeightRecord(let writeId, let record):
            self = .createWeightRecord(
                .init(
                    id: writeId.uuidString,
                    _type: .createWeightRecord,
                    weightRecord: .init(
                        id: record.id.uuidString,
                        weightKg: record.weightKilograms,
                        measuredAt: record.measuredAt.millisecondsSince1970,
                        timeZone: record.timeZone.identifier,
                        imported: record.imported.map { imported in
                            .init(
                                sourceAppName: imported.sourceAppName,
                                sourceBundleId: imported.sourceBundleId,
                                healthkitSampleUuid: imported.healthKitSampleId.uuidString,
                                bodyFat: imported.bodyFat.map { bodyFat in
                                    .init(
                                        percentage: bodyFat.percentage,
                                        healthkitSampleUuid: bodyFat.healthKitSampleId.uuidString
                                    )
                                }
                            )
                        }
                    )
                )
            )
        case .updateWeightRecord(let writeId, let correction):
            self = .updateWeightRecord(
                .init(
                    id: writeId.uuidString,
                    _type: .updateWeightRecord,
                    weightRecord: .init(
                        id: correction.id.uuidString,
                        weightKg: correction.weightKilograms,
                        measuredAt: correction.measuredAt.millisecondsSince1970,
                        timeZone: correction.timeZone.identifier,
                        version: correction.version
                    )
                )
            )
        }
    }
}

extension Operations.PushSyncWrites.Input.Body.JsonPayload.ClientStatePayload {
    fileprivate init(_ clientState: SyncClientState) {
        self.init(
            deviceId: clientState.deviceId.uuidString,
            timeZone: clientState.timeZone.identifier,
            appVersion: clientState.appVersion,
            osVersion: clientState.osVersion,
            pendingWriteCount: clientState.pendingWriteCount,
            oldestPendingWriteAgeSeconds: clientState.oldestPendingWriteAge.map {
                Int($0.components.seconds)
            },
            pendingPhotoCount: clientState.pendingPhotoCount
        )
    }
}

extension Operations.PullSyncChanges.Input.Query {
    fileprivate init(_ clientState: SyncClientState, afterSequence: Int) {
        self.init(
            deviceId: clientState.deviceId.uuidString,
            timeZone: clientState.timeZone.identifier,
            appVersion: clientState.appVersion,
            osVersion: clientState.osVersion,
            pendingWriteCount: clientState.pendingWriteCount,
            oldestPendingWriteAgeSeconds: clientState.oldestPendingWriteAge.map {
                Int($0.components.seconds)
            },
            pendingPhotoCount: clientState.pendingPhotoCount,
            afterSequence: afterSequence
        )
    }
}

extension SyncWriteResult {
    fileprivate init(_ result: Components.Schemas.SyncWriteResult) throws {
        guard let writeId = UUID(uuidString: result.writeId) else {
            throw NuToriAPIClient.MalformedResponseError(reason: "書き込みの ID が UUID でない")
        }
        switch result.result {
        case "applied":
            self.init(writeId: writeId, outcome: .applied)
        case "ignored_duplicate":
            self.init(writeId: writeId, outcome: .ignoredDuplicate)
        case "rejected":
            guard let reason = result.rejectionReason else {
                throw NuToriAPIClient.MalformedResponseError(reason: "受け付けなかった理由が無い")
            }
            self.init(writeId: writeId, outcome: .rejected(RejectionReason(reason)))
        default:
            self.init(writeId: writeId, outcome: .unknown(result: result.result))
        }
    }
}

extension SyncWriteResult.RejectionReason {
    fileprivate init(_ reason: String) {
        switch reason {
        case "out_of_range": self = .outOfRange
        case "invalid_time_zone": self = .invalidTimeZone
        case "version_too_low": self = .versionTooLow
        case "record_not_found": self = .recordNotFound
        case "record_before_started_on": self = .recordBeforeStartedOn
        default: self = .unknown(reason: reason)
        }
    }
}

extension SyncChangesPage {
    fileprivate init(_ body: Operations.PullSyncChanges.Output.Ok.Body.JsonPayload) {
        self.init(
            changes: body.changes.map(SyncChange.init),
            hasMore: body.hasMore,
            nextAfterSequence: body.nextAfterSequence,
            startedOn: body.startedOn
        )
    }
}

extension SyncChange {
    fileprivate init(_ change: Components.Schemas.SyncChange) {
        switch change.kind {
        case "weight_record":
            if let record = try? WeightRecordPayload(change.record).syncedWeightRecord {
                self = .weightRecord(record)
            } else {
                self = .unknown(kind: change.kind)
            }
        default:
            self = .unknown(kind: change.kind)
        }
    }

    fileprivate struct WeightRecordPayload: Decodable {
        let id: String
        let weightKg: Double
        let measuredAt: Int
        let timeZone: String
        let version: Int
        let imported: Imported?

        struct Imported: Decodable {
            let sourceAppName: String
            let sourceBundleId: String
            let healthkitSampleUuid: String
            let bodyFat: BodyFat?

            struct BodyFat: Decodable {
                let percentage: Double
                let healthkitSampleUuid: String
            }
        }

        init(_ record: Components.Schemas.SyncChange.RecordPayload) throws {
            let json = try JSONEncoder().encode(record)
            self = try JSONDecoder().decode(Self.self, from: json)
        }

        var syncedWeightRecord: SyncedWeightRecord? {
            guard let id = UUID(uuidString: id), let timeZone = TimeZone(identifier: timeZone)
            else {
                return nil
            }
            var importedSource: SyncedWeightRecord.Imported?
            if let imported {
                guard let sampleId = UUID(uuidString: imported.healthkitSampleUuid) else {
                    return nil
                }
                var bodyFat: SyncedWeightRecord.Imported.BodyFat?
                if let payload = imported.bodyFat {
                    guard let bodyFatSampleId = UUID(uuidString: payload.healthkitSampleUuid) else {
                        return nil
                    }
                    bodyFat = .init(
                        percentage: payload.percentage, healthKitSampleId: bodyFatSampleId)
                }
                importedSource = .init(
                    sourceAppName: imported.sourceAppName,
                    sourceBundleId: imported.sourceBundleId,
                    healthKitSampleId: sampleId,
                    bodyFat: bodyFat
                )
            }
            return SyncedWeightRecord(
                id: id,
                weightKilograms: weightKg,
                measuredAt: Date(timeIntervalSince1970: Double(measuredAt) / 1000),
                timeZone: timeZone,
                version: version,
                imported: importedSource
            )
        }
    }
}

extension Date {
    fileprivate var millisecondsSince1970: Int {
        Int((timeIntervalSince1970 * 1000).rounded())
    }
}
