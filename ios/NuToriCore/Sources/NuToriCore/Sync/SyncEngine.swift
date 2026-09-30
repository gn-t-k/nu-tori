public import Foundation
public import NuToriAPI

public actor SyncEngine {
    /// 新しい種類の記録を読めるようにしたら上げる。上げると、更新して最初の同期で全部取り直す
    public static let currentReadableKindsVersion = 2

    public init(
        store: any SyncStore,
        client: NuToriAPIClient,
        accountId: String,
        device: SyncDevice,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        readableKindsVersion: Int,
        errorReporting: any ErrorReportingSession
    ) {
        self.store = store
        self.client = client
        self.accountId = accountId
        self.device = device
        self.timeZone = timeZone
        self.now = now
        self.readableKindsVersion = readableKindsVersion
        self.errorReporting = errorReporting
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
            try await writingCache {
                try await store.save(record, enqueuing: pendingWrite(.createWeightRecord(record)))
            }
        case .correct(let record):
            guard let previous = try await store.weightRecord(id: record.id) else {
                throw UnknownRecordError(recordId: record.id)
            }
            try await writingCache {
                try await store.save(
                    record,
                    enqueuing: pendingWrite(.correctWeightRecord(record, previous: previous))
                )
            }
        }
    }

    /// 利用状況を送るかの切り替え。電波が無くても受け付け、送り待ちに並べる
    public func setSendsUsageData(_ sendsUsageData: Bool) async throws {
        let settings = AccountSettings(
            id: AccountSettings.id(forAccountId: accountId),
            sendsUsageData: sendsUsageData
        )
        try await writingCache {
            try await store.save(
                settings, enqueuing: pendingWrite(.updateAccountSettings(settings)))
        }
    }

    public func usageDataSetting() async throws -> UsageDataSetting {
        UsageDataSetting(
            accountSettings: try await store.accountSettings(),
            hasCompletedInitialPull: try await store.syncState()?.hasCompletedInitialPull ?? false
        )
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

    private let store: any SyncStore
    private let client: NuToriAPIClient
    private let accountId: String
    private let device: SyncDevice
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let readableKindsVersion: Int
    private let errorReporting: any ErrorReportingSession

    private func pendingWrite(_ operation: PendingWrite.Operation) -> PendingWrite {
        PendingWrite(writeId: UUID(), enqueuedAt: now(), operation: operation)
    }

    private func pushPendingWrites(collectingRejectionsIn rejectedWrites: inout [RejectedWrite])
        async throws -> SyncResult.StopReason?
    {
        let maxWritesPerRequest = 500
        let pending = try await store.pendingWritesOldestFirst()
        // 先の要求で作る書き込みが受け付けられず消した記録を、あとの要求の直す書き込みで戻さない
        var revertedRecordIds: Set<UUID> = []
        for batchStart in stride(from: 0, to: pending.count, by: maxWritesPerRequest) {
            let batchEnd = min(batchStart + maxWritesPerRequest, pending.count)
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
                if let failure = HandledFailure.reported(error, as: .sync) {
                    await errorReporting.report(failure)
                }
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
            case .applied, .ignoredDuplicate, .ignoredTombstone, .keptCorrected, .unknown:
                break
            case .rejected(let reason):
                switch write.operation {
                case .createWeightRecord(let record):
                    rejectedWrites.append(
                        RejectedWrite(writeId: write.writeId, record: record, reason: reason))
                    if revertedRecordIds.insert(record.id).inserted {
                        reversions.append(.remove(recordId: record.id))
                    }
                case .correctWeightRecord(let record, let previous):
                    rejectedWrites.append(
                        RejectedWrite(writeId: write.writeId, record: record, reason: reason))
                    if revertedRecordIds.insert(record.id).inserted {
                        reversions.append(.restore(previous))
                    }
                case .sourceDeletedWeightRecord:
                    // 戻す記録も、画面に出す記録も無い。消すかどうかを決めるのはサーバーで、送り直さない
                    break
                case .updateAccountSettings:
                    // サーバーはアカウントの設定を受け付けないことが無いので、戻す先も画面に出すものも無い
                    break
                }
            }
        }
        try await writingCache {
            try await store.removePendingWrites(resolvedWriteIds, reverting: reversions)
        }
    }

    private func pullChanges() async throws -> SyncResult.StopReason? {
        var state = try await syncStateReadingCurrentKinds()
        while true {
            let result: NuToriAPIClient.PullSyncChangesResult
            do {
                result = try await client.pullSyncChanges(
                    afterSequence: state.afterSequence,
                    clientState: clientState(
                        pendingWrites: try await store.pendingWritesOldestFirst()[...])
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if let failure = HandledFailure.reported(error, as: .sync) {
                    await errorReporting.report(failure)
                }
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
                try await writingCache {
                    try await store.apply(
                        PulledChanges(
                            records: page.changes.compactMap(\.weightRecord),
                            removedRecordIds: page.changes.compactMap(\.removedRecordId),
                            accountSettings: page.changes.compactMap(\.accountSettings).last,
                            state: state
                        )
                    )
                }
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
        try await writingCache {
            try await store.saveSyncState(restarted)
        }
        return restarted
    }

    private func writingCache<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let failure = HandledFailure.reported(error, as: .cacheSave) {
                await errorReporting.report(failure)
            }
            throw error
        }
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
            .createWeightRecord(writeId: writeId, record: NewWeightRecord(record))
        case .correctWeightRecord(let record, previous: _):
            .updateWeightRecord(writeId: writeId, correction: WeightRecordCorrection(record))
        case .sourceDeletedWeightRecord(let recordId):
            .sourceDeletedWeightRecord(writeId: writeId, weightRecordId: recordId)
        case .updateAccountSettings(let settings):
            .updateAccountSettings(
                writeId: writeId,
                settings: SyncedAccountSettings(
                    id: settings.id, sendsUsageData: settings.sendsUsageData)
            )
        }
    }
}

extension SyncChange {
    fileprivate var weightRecord: WeightRecord? {
        switch self {
        case .weightRecord(let record): WeightRecord(record)
        case .accountSettings, .weightRecordDeletion, .unknown: nil
        }
    }

    fileprivate var removedRecordId: UUID? {
        switch self {
        case .weightRecordDeletion(let recordId): recordId
        case .weightRecord, .accountSettings, .unknown: nil
        }
    }

    fileprivate var accountSettings: AccountSettings? {
        switch self {
        case .accountSettings(let settings):
            AccountSettings(id: settings.id, sendsUsageData: settings.sendsUsageData)
        case .weightRecord, .weightRecordDeletion, .unknown: nil
        }
    }
}

extension NewWeightRecord {
    fileprivate init(_ record: WeightRecord) {
        self.init(
            id: record.id,
            weightKilograms: record.kilograms,
            measuredAt: record.instant,
            timeZone: record.timeZone,
            imported: record.inputSource.importedSource.map { source in
                SyncedWeightRecord.Imported(
                    sourceAppName: source.appName,
                    sourceBundleId: source.bundleId,
                    healthKitSampleId: source.healthKitSampleId,
                    bodyFat: source.bodyFat.map {
                        SyncedWeightRecord.Imported.BodyFat(
                            percentage: $0.percentage,
                            healthKitSampleId: $0.healthKitSampleId
                        )
                    }
                )
            }
        )
    }
}

extension WeightRecordCorrection {
    fileprivate init(_ record: WeightRecord) {
        self.init(
            id: record.id,
            weightKilograms: record.kilograms,
            measuredAt: record.instant,
            timeZone: record.timeZone,
            version: record.version
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
