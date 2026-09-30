public import Foundation
public import NuToriAPI

public actor SyncEngine {
    /// `readableKinds` は今読める種類の名前（登録簿の名前の集合）。前に読めた種類に無い名前があると、全部取り直す
    public init(
        store: any SyncBox & RecordCacheReading,
        client: NuToriAPIClient,
        accountId: String,
        device: SyncDevice,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        readableKinds: Set<String>,
        errorReporting: any ErrorReportingSession,
        weightHealthExport: any WeightHealthExport
    ) {
        self.store = store
        self.client = client
        self.accountId = accountId
        self.device = device
        self.timeZone = timeZone
        self.now = now
        self.readableKinds = readableKinds
        self.errorReporting = errorReporting
        self.weightHealthExport = weightHealthExport
    }

    @discardableResult
    public func save(_ write: WeightEntry.Write) async throws -> WeightRecord {
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
                try await store.apply(
                    WeightRecordSyncing().saving(
                        record, enqueuing: pendingWrite(.createWeightRecord(record))))
            }
            return record
        case .correct(let record):
            guard let previous = try await store.weightRecord(id: record.id) else {
                throw UnknownRecordError(recordId: record.id)
            }
            try await writingCache {
                try await store.apply(
                    WeightRecordSyncing().saving(
                        record,
                        enqueuing: pendingWrite(.correctWeightRecord(record, previous: previous))
                    )
                )
            }
            return record
        }
    }

    /// 利用状況を送るかの切り替え。電波が無くても受け付け、送り待ちに並べる
    public func setSendsUsageData(_ sendsUsageData: Bool) async throws {
        let settings = AccountSettings(
            id: AccountSettings.id(forAccountId: accountId),
            sendsUsageData: sendsUsageData
        )
        try await writingCache {
            try await store.apply(
                AccountSettingsSyncKind().saving(
                    settings, enqueuing: pendingWrite(.updateAccountSettings(settings))))
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

    private let store: any SyncBox & RecordCacheReading
    private let client: NuToriAPIClient
    private let accountId: String
    private let device: SyncDevice
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let readableKinds: Set<String>
    private let errorReporting: any ErrorReportingSession
    private let weightHealthExport: any WeightHealthExport

    private func pendingWrite(_ operation: PendingWrite.Operation) -> PendingWrite {
        PendingWrite(writeId: UUID(), enqueuedAt: now(), operation: operation)
    }

    private func pushPendingWrites(collectingRejectionsIn rejectedWrites: inout [RejectedWrite])
        async throws -> SyncResult.StopReason?
    {
        let maxWritesPerRequest = 500
        let pending = try await store.pendingEntries()
        // 先の要求で作る書き込みが受け付けられず消した記録を、あとの要求の直す書き込みで戻さない
        var revertedRecordIds: Set<UUID> = []
        for batchStart in stride(from: 0, to: pending.count, by: maxWritesPerRequest) {
            let batchEnd = min(batchStart + maxWritesPerRequest, pending.count)
            let batch = Array(pending[batchStart..<batchEnd])
            let writes = try batch.map(syncWrite)
            let result: NuToriAPIClient.PushSyncWritesResult
            do {
                result = try await client.pushSyncWrites(
                    writes,
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

    private func kind(named name: String) throws -> any SyncedRecordKind {
        guard let kind = store.recordKinds.first(where: { $0.name == name }) else {
            throw UnknownRecordKindError(kind: name)
        }
        return kind
    }

    /// 種類が、送る書き込みにする
    private func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        try kind(named: entry.kind).syncWrite(for: entry)
    }

    private func resolve(
        _ batch: [PendingEntry],
        with results: [SyncWriteResult],
        revertedRecordIds: inout Set<UUID>,
        rejectedWrites: inout [RejectedWrite]
    ) async throws {
        let outcomes = Dictionary(
            results.map { ($0.writeId, $0.outcome) },
            uniquingKeysWith: { first, _ in first }
        )
        var resolvedWriteIds: [UUID] = []
        var revertingChanges: [String: [SyncChange]] = [:]
        for entry in batch {
            guard let outcome = outcomes[entry.writeId] else {
                continue
            }
            resolvedWriteIds.append(entry.writeId)
            switch outcome {
            case .applied, .ignoredDuplicate, .ignoredTombstone, .keptCorrected, .unknown:
                break
            case .rejected(let reason):
                let kind = try kind(named: entry.kind)
                let rejection = try kind.rejection(
                    of: entry, reason: reason, revertedRecordIds: &revertedRecordIds)
                if let rejected = rejection.rejectedWrite {
                    rejectedWrites.append(rejected)
                }
                revertingChanges[kind.name, default: []] += rejection.revertingChanges
            }
        }
        try await writingCache {
            try await store.apply(
                SyncBoxResult(
                    resolvedWriteIds: resolvedWriteIds,
                    kindChanges: revertingChanges.filter { !$0.value.isEmpty }
                        .sorted { $0.key < $1.key }
                        .map { KindChanges(kind: $0.key, changes: $0.value) }
                ))
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
                        pendingWrites: try await store.pendingEntries()[...])
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
                let kinds = store.recordKinds
                // 登録簿に無い種類の変更は読み飛ばす。名前がサーバーとそろっているかは、テストで見張る
                let ownedChanges = kinds.map { kind in
                    KindChanges(kind: kind.name, changes: page.changes.filter { kind.owns($0) })
                }.filter { !$0.changes.isEmpty }
                // ヘルスケアへの書き直しは、届いた体重記録に行う
                let revised = try await revisedManualRecords(
                    in: WeightRecordSyncing().current(from: page.changes).records)
                state = SyncState(
                    afterSequence: page.nextAfterSequence,
                    hasCompletedInitialPull: state.hasCompletedInitialPull || !page.hasMore,
                    readableKinds: readableKinds,
                    startedOn: page.startedOn
                )
                try await writingCache {
                    try await store.apply(
                        SyncBoxResult(kindChanges: ownedChanges, syncState: state))
                }
                try await exportRevisedRecords(revised)
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
                readableKinds: readableKinds,
                startedOn: nil
            )
        }
        if readableKinds.isSubset(of: saved.readableKinds) {
            return saved
        }
        // 途中で終わっても、次は戻した通し番号の続きから取れるよう、すぐ保存する
        let restarted = SyncState(
            afterSequence: 0,
            hasCompletedInitialPull: saved.hasCompletedInitialPull,
            readableKinds: readableKinds,
            startedOn: saved.startedOn
        )
        try await writingCache {
            try await store.apply(SyncBoxResult(syncState: restarted))
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

    private func revisedManualRecords(in incoming: [WeightRecord]) async throws -> [WeightRecord] {
        var revised: [WeightRecord] = []
        for record in incoming {
            switch record.inputSource {
            case .imported:
                continue
            case .manual:
                guard let cached = try await store.weightRecord(id: record.id),
                    record.version > cached.version
                else { continue }
                revised.append(record)
            }
        }
        return revised
    }

    /// 書き直しに失敗しても、届いた記録はキャッシュに残す。次に版が上がったときに書き直す
    private func exportRevisedRecords(_ records: [WeightRecord]) async throws {
        for record in records {
            do {
                try await weightHealthExport.exportWeightRecord(record)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
    }

    private func clientState(pendingWrites: ArraySlice<PendingEntry>) -> SyncClientState {
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
