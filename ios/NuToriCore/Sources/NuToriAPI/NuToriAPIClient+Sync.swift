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
                    writes: try writes.map { try $0.wire().body },
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

extension Operations.PushSyncWrites.Input.Body.JsonPayload.ClientStatePayload {
    fileprivate init(_ clientState: SyncClientState) {
        self.init(
            deviceId: clientState.deviceId.canonicalString,
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
            deviceId: clientState.deviceId.canonicalString,
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
            self.init(writeId: writeId, outcome: .applied, current: nil)
        case "ignored_duplicate":
            self.init(writeId: writeId, outcome: .ignoredDuplicate, current: nil)
        case "ignored_tombstone":
            self.init(writeId: writeId, outcome: .ignoredTombstone, current: nil)
        case "kept_corrected":
            self.init(writeId: writeId, outcome: .keptCorrected, current: nil)
        case "rejected":
            guard let reason = result.rejectionReason else {
                throw NuToriAPIClient.MalformedResponseError(reason: "受け付けなかった理由が無い")
            }
            self.init(
                writeId: writeId,
                outcome: .rejected(RejectionReason(reason)),
                current: result.current.flatMap(Current.init)
            )
        default:
            self.init(writeId: writeId, outcome: .unknown(result: result.result), current: nil)
        }
    }
}

extension SyncWriteResult.Current {
    /// 知らない状態と、読めない中身は nil にする。サーバーが状態を足しても、古い版のアプリの同期が止まらないように
    fileprivate init?(_ current: Components.Schemas.SyncWriteCurrent) {
        switch current.status {
        case "value":
            guard let change = current.change.map(SyncChange.init) else { return nil }
            self = .value(change)
        case "deleted":
            guard let change = current.change.map(SyncChange.init) else { return nil }
            self = .deleted(change)
        case "absent":
            self = .absent
        default:
            return nil
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
        case "invalid_entry_method": self = .invalidEntryMethod
        case "duplicate_photo_ids": self = .duplicatePhotoIds
        case "photo_already_used": self = .photoAlreadyUsed
        case "invalid_notice_type": self = .invalidNoticeType
        case "invalid_target_on": self = .invalidTargetOn
        case "ingredients_replaced": self = .ingredientsReplaced
        case "awaiting_estimation": self = .awaitingEstimation
        case "not_classified_as_meal": self = .notClassifiedAsMeal
        case "reply_not_failed": self = .replyNotFailed
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
        self = RecordKindWireCodings.change(
            wireKind: change.kind, recordId: change.recordId, record: change.record)
    }

    /// 受け付けなかった書き込みに添えられた今の値も、取りに行く変更と同じ道で読む
    fileprivate init(_ change: Components.Schemas.SyncWriteCurrent.ChangePayload) {
        self = RecordKindWireCodings.change(
            wireKind: change.kind, recordId: change.recordId, record: change.record)
    }
}
