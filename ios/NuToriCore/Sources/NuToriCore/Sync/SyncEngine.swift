public import Foundation
public import NuToriAPI

public actor SyncEngine {
    /// 新しい種類の記録を読めるようにしたら上げる。上げると、更新して最初の同期で全部取り直す
    public static let currentReadableKindsVersion = 1

    public init(
        store: any SyncStore,
        client: NuToriAPIClient,
        device: SyncDevice,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        readableKindsVersion: Int
    ) {
        self.store = store
        self.client = client
        self.device = device
        self.timeZone = timeZone
        self.now = now
        self.readableKindsVersion = readableKindsVersion
    }

    public func save(_ write: WeightEntry.Write) async throws {
        switch write {
        case .create(let kilograms, let instant, let timeZone):
            let record = WeightRecord(
                id: UUID(),
                kilograms: kilograms,
                instant: instant,
                timeZone: timeZone,
                inputSource: .manual,
                version: 1
            )
            try await store.save(record, enqueuing: pendingWrite(.createWeightRecord(record)))
        case .correct(let record):
            guard let previous = try await store.weightRecord(id: record.id) else {
                throw UnknownRecordError(recordId: record.id)
            }
            try await store.save(
                record,
                enqueuing: pendingWrite(.correctWeightRecord(record, previous: previous))
            )
        }
    }

    public func sync() async throws -> SyncResult {
        var rejectedWrites: [RejectedWrite] = []
        let stoppedBy: SyncResult.StopReason?
        if let pushStop = try await pushPendingWrites(collectingRejectionsIn: &rejectedWrites) {
            stoppedBy = pushStop
        } else {
            stoppedBy = try await pullChanges()
        }
        return SyncResult(
            rejectedWrites: rejectedWrites,
            ending: stoppedBy.map { .stopped($0) } ?? .finished
        )
    }

    public struct UnknownRecordError: Error, Equatable {
        public let recordId: UUID

        public init(recordId: UUID) {
            self.recordId = recordId
        }
    }

    private static let maxWritesPerRequest = 500

    private let store: any SyncStore
    private let client: NuToriAPIClient
    private let device: SyncDevice
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let readableKindsVersion: Int

    private func pendingWrite(_ operation: PendingWrite.Operation) -> PendingWrite {
        PendingWrite(writeId: UUID(), enqueuedAt: now(), operation: operation)
    }

    private func pushPendingWrites(collectingRejectionsIn rejectedWrites: inout [RejectedWrite])
        async throws -> SyncResult.StopReason?
    {
        let pending = try await store.pendingWrites()
        // 先の要求で作る書き込みが受け付けられず消した記録を、あとの要求の直す書き込みで戻さない
        var revertedRecordIds: Set<UUID> = []
        for batchStart in stride(from: 0, to: pending.count, by: Self.maxWritesPerRequest) {
            let batchEnd = min(batchStart + Self.maxWritesPerRequest, pending.count)
            let batch = Array(pending[batchStart..<batchEnd])
            let result: NuToriAPIClient.PushSyncWritesResult
            do {
                result = try await client.pushSyncWrites(
                    batch.map(\.syncWrite),
                    isFinalBatch: batchEnd == pending.count,
                    clientState: clientState(pendingWrites: pending[batchStart...])
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .unavailable
            }
            switch result {
            case .pushed(let results):
                try await resolve(
                    batch,
                    with: results,
                    revertedRecordIds: &revertedRecordIds,
                    rejectedWrites: &rejectedWrites
                )
            case .badRequest:
                return .badRequest
            case .sessionExpired:
                return .sessionExpired
            case .rateLimited:
                return .rateLimited
            }
        }
        return nil
    }

    private func resolve(
        _ batch: [PendingWrite],
        with results: [SyncWriteResult],
        revertedRecordIds: inout Set<UUID>,
        rejectedWrites: inout [RejectedWrite]
    ) async throws {
        let outcomes = Dictionary(
            results.map { ($0.writeId, $0.outcome) },
            uniquingKeysWith: { first, _ in first }
        )
        var resolvedWriteIds: [UUID] = []
        var reversions: [RecordReversion] = []
        for write in batch {
            guard let outcome = outcomes[write.writeId] else {
                continue
            }
            resolvedWriteIds.append(write.writeId)
            switch outcome {
            case .applied, .ignoredDuplicate, .unknown:
                break
            case .rejected(let reason):
                rejectedWrites.append(
                    RejectedWrite(
                        writeId: write.writeId,
                        record: write.operation.record,
                        reason: reason
                    )
                )
                if revertedRecordIds.insert(write.operation.record.id).inserted {
                    reversions.append(write.operation.reversion)
                }
            }
        }
        try await store.removePendingWrites(resolvedWriteIds, reverting: reversions)
    }

    private func pullChanges() async throws -> SyncResult.StopReason? {
        var state = try await syncStateReadingCurrentKinds()
        while true {
            let result: NuToriAPIClient.PullSyncChangesResult
            do {
                result = try await client.pullSyncChanges(
                    afterSequence: state.afterSequence,
                    clientState: clientState(pendingWrites: try await store.pendingWrites()[...])
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .unavailable
            }
            switch result {
            case .pulled(let page):
                state = SyncState(
                    afterSequence: page.nextAfterSequence,
                    hasCompletedInitialPull: state.hasCompletedInitialPull || !page.hasMore,
                    readableKindsVersion: readableKindsVersion,
                    startedOn: page.startedOn
                )
                try await store.apply(
                    PulledChanges(records: page.changes.compactMap(\.weightRecord), state: state)
                )
                if !page.hasMore {
                    return nil
                }
            case .badRequest:
                return .badRequest
            case .sessionExpired:
                return .sessionExpired
            case .rateLimited:
                return .rateLimited
            }
        }
    }

    private func syncStateReadingCurrentKinds() async throws -> SyncState {
        guard let saved = try await store.syncState() else {
            return SyncState(
                afterSequence: 0,
                hasCompletedInitialPull: false,
                readableKindsVersion: readableKindsVersion,
                startedOn: nil
            )
        }
        guard saved.readableKindsVersion != readableKindsVersion else {
            return saved
        }
        // 途中で終わっても、次は戻した通し番号の続きから取れるよう、すぐ保存する
        let restarted = SyncState(
            afterSequence: 0,
            hasCompletedInitialPull: saved.hasCompletedInitialPull,
            readableKindsVersion: readableKindsVersion,
            startedOn: saved.startedOn
        )
        try await store.saveSyncState(restarted)
        return restarted
    }

    private func clientState(pendingWrites: ArraySlice<PendingWrite>) -> SyncClientState {
        let currentTime = now()
        return SyncClientState(
            deviceId: device.deviceId,
            timeZone: timeZone(),
            appVersion: device.appVersion,
            osVersion: device.osVersion,
            pendingWriteCount: pendingWrites.count,
            oldestPendingWriteAge: pendingWrites.map(\.enqueuedAt).min().map {
                .seconds(max(0, currentTime.timeIntervalSince($0)))
            },
            pendingPhotoCount: 0
        )
    }
}

extension PendingWrite {
    fileprivate var syncWrite: SyncWrite {
        switch operation {
        case .createWeightRecord(let record):
            .createWeightRecord(writeId: writeId, record: SyncedWeightRecord(record))
        case .correctWeightRecord(let record, previous: _):
            .updateWeightRecord(writeId: writeId, record: SyncedWeightRecord(record))
        }
    }
}

extension PendingWrite.Operation {
    fileprivate var record: WeightRecord {
        switch self {
        case .createWeightRecord(let record), .correctWeightRecord(let record, previous: _):
            record
        }
    }

    fileprivate var reversion: RecordReversion {
        switch self {
        case .createWeightRecord(let record):
            .remove(recordId: record.id)
        case .correctWeightRecord(_, let previous):
            .restore(previous)
        }
    }
}

extension SyncChange {
    fileprivate var weightRecord: WeightRecord? {
        switch self {
        case .weightRecord(let record): WeightRecord(record)
        case .unknown: nil
        }
    }
}

extension SyncedWeightRecord {
    fileprivate init(_ record: WeightRecord) {
        self.init(
            id: record.id,
            weightKilograms: record.kilograms,
            measuredAt: record.instant,
            timeZone: record.timeZone,
            version: record.version,
            imported: record.inputSource.importedSource.map { source in
                Imported(
                    sourceAppName: source.appName,
                    sourceBundleId: source.bundleId,
                    healthKitSampleId: source.healthKitSampleId,
                    bodyFat: source.bodyFat.map {
                        Imported.BodyFat(
                            percentage: $0.percentage,
                            healthKitSampleId: $0.healthKitSampleId
                        )
                    }
                )
            }
        )
    }
}

extension WeightRecord {
    fileprivate init(_ record: SyncedWeightRecord) {
        self.init(
            id: record.id,
            kilograms: record.weightKilograms,
            instant: record.measuredAt,
            timeZone: record.timeZone,
            inputSource: record.imported.map { imported in
                .imported(
                    ImportedSource(
                        appName: imported.sourceAppName,
                        bundleId: imported.sourceBundleId,
                        healthKitSampleId: imported.healthKitSampleId,
                        bodyFat: imported.bodyFat.map {
                            ImportedSource.BodyFat(
                                percentage: $0.percentage,
                                healthKitSampleId: $0.healthKitSampleId
                            )
                        }
                    )
                )
            } ?? .manual,
            version: record.version
        )
    }
}

extension WeightRecord.InputSource {
    fileprivate var importedSource: WeightRecord.ImportedSource? {
        switch self {
        case .manual: nil
        case .imported(let source): source
        }
    }
}
