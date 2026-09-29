public import Foundation

public actor HealthSyncEngine {
    public init(
        healthStore: any HealthStore,
        store: any SyncStore,
        ownBundleId: String,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date
    ) {
        self.healthStore = healthStore
        self.store = store
        self.ownBundleId = ownBundleId
        self.timeZone = timeZone
        self.now = now
    }

    public func requestAuthorizationOnFirstWeightEntry() async throws {
        try await requestAuthorizationIfNotYetRequested()
    }

    public func requestAuthorizationAfterInitialPull() async throws {
        guard try await store.syncState()?.hasCompletedInitialPull == true,
            try await !store.weightRecords().isEmpty
        else {
            return
        }
        try await requestAuthorizationIfNotYetRequested()
    }

    public func importChanges() async throws {
        let state = try await store.healthSyncState()
        let readBoundary = try await healthStore.earliestAuthorizedSampleDate()
        let changes = try await healthStore.readWeightChanges(
            after: state.anchor,
            notBefore: readBoundary
        )
        var cachedRecords: [UUID: WeightRecord] = [:]
        for recordId in HealthImportPlan.affectedRecordIds(in: changes) {
            cachedRecords[recordId] = try await store.weightRecord(id: recordId)
        }
        let plan = HealthImportPlan(
            changes: changes,
            ownBundleId: ownBundleId,
            deviceTimeZone: timeZone(),
            readBoundary: readBoundary,
            cachedRecords: cachedRecords
        )
        try await store.applyHealthImport(
            HealthImportBatch(
                records: plan.newRecords,
                pendingWrites: plan.newRecords.map { pendingWrite(.createWeightRecord($0)) }
                    + plan.deletedRecordIds.map {
                        pendingWrite(.sourceDeletedWeightRecord(recordId: $0))
                    },
                state: HealthSyncState(
                    anchor: changes.anchor,
                    hasWrittenCachedManualRecords: state.hasWrittenCachedManualRecords
                )
            )
        )
    }

    /// 記録を作った・直したとき、取りに行って版が上がった手の記録が届いたときに、その場で書く
    public func exportWeightRecord(_ record: WeightRecord) async throws {
        guard record.isManual, try await healthStore.isWeightWriteAuthorized() else {
            return
        }
        try await healthStore.writeWeight(HealthWeightWrite(record))
    }

    public func exportCachedManualRecordsOnNewWriteAuthorization() async throws {
        let state = try await store.healthSyncState()
        guard !state.hasWrittenCachedManualRecords,
            try await healthStore.isWeightWriteAuthorized()
        else {
            return
        }
        for record in try await store.weightRecords() where record.isManual {
            try await healthStore.writeWeight(HealthWeightWrite(record))
        }
        try await store.saveHealthSyncState(
            HealthSyncState(anchor: state.anchor, hasWrittenCachedManualRecords: true)
        )
    }

    private let healthStore: any HealthStore
    private let store: any SyncStore
    private let ownBundleId: String
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date

    private func requestAuthorizationIfNotYetRequested() async throws {
        guard try await healthStore.authorizationRequestStatus() == .notYetRequested else {
            return
        }
        try await healthStore.requestAuthorization()
    }

    private func pendingWrite(_ operation: PendingWrite.Operation) -> PendingWrite {
        PendingWrite(writeId: UUID(), enqueuedAt: now(), operation: operation)
    }
}

extension WeightRecord {
    fileprivate var isManual: Bool {
        switch inputSource {
        case .manual: true
        case .imported: false
        }
    }
}

extension HealthWeightWrite {
    fileprivate init(_ record: WeightRecord) {
        self.init(
            syncId: record.id,
            syncVersion: record.version,
            kilograms: record.kilograms,
            instant: record.instant,
            timeZone: record.timeZone
        )
    }
}
