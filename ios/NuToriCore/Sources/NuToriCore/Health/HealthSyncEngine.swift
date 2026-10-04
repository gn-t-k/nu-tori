public import Foundation

public actor HealthSyncEngine {
    public init(
        healthStore: any HealthStore,
        store: any SyncBox & RecordCacheReading & HealthSyncStoring & HealthDishWriteStoring,
        ownBundleId: String,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        errorReporting: any ErrorReportingSession
    ) {
        self.healthStore = healthStore
        self.store = store
        self.ownBundleId = ownBundleId
        self.timeZone = timeZone
        self.now = now
        self.errorReporting = errorReporting
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
        let readBoundary = try await reporting(.healthRead) {
            try await healthStore.earliestAuthorizedSampleDate()
        }
        let changes = try await reporting(.healthRead) {
            try await healthStore.readWeightChanges(
                after: state.anchor,
                notBefore: readBoundary
            )
        }
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
        try await writingCache {
            try await store.apply(
                WeightRecordSyncing().importing(
                    plan.newRecords,
                    sourceDeletedRecordIds: plan.deletedRecordIds,
                    now: now,
                    healthSyncState: HealthSyncState(
                        anchor: changes.anchor,
                        hasWrittenCachedManualRecords: state.hasWrittenCachedManualRecords
                    )
                )
            )
        }
    }

    /// 記録を作った・直したとき、取りに行って版が上がった手の記録が届いたときに、その場で書く
    public func exportWeightRecord(_ record: WeightRecord) async throws {
        guard record.isManual, try await healthStore.isWeightWriteAuthorized() else {
            return
        }
        try await reporting(.healthWrite) {
            try await healthStore.writeWeight(HealthWeightWrite(record))
        }
    }

    public func exportCachedManualRecordsOnNewWriteAuthorization() async throws {
        let state = try await store.healthSyncState()
        guard !state.hasWrittenCachedManualRecords,
            try await healthStore.isWeightWriteAuthorized()
        else {
            return
        }
        for record in try await store.weightRecords() where record.isManual {
            try await reporting(.healthWrite) {
                try await healthStore.writeWeight(HealthWeightWrite(record))
            }
        }
        try await writingCache {
            try await store.apply(
                SyncBoxResult(
                    healthSyncState: HealthSyncState(
                        anchor: state.anchor, hasWrittenCachedManualRecords: true)
                )
            )
        }
    }

    /// この端末で初めて食事を記録したあと、水分を除いた栄養の書き込みの許可を求める。
    /// 求めたら、許可の画面が閉じたあとに、キャッシュにある料理をまとめて書く。求め済みなら何もしない
    public func requestNutritionAuthorizationAfterMealRecorded() async throws {
        guard try await healthStore.nutritionAuthorizationRequestStatus() == .notYetRequested
        else {
            return
        }
        try await healthStore.requestNutritionAuthorization()
        try await exportNutrition()
    }

    /// 書き込みを許可された種類があるとき、推定できた食事の料理でまだ書いていない（書いた版より新しい）ものを書き、
    /// 食事や料理が無くなった料理を消す。書いた料理は、許可された種類が増えても書き直さない。
    /// 食事がまだ無い料理と、推定できていない食事の料理は、そろうまで待つ。
    /// ヘルスケアに書く・消すことの失敗は、残りの料理を試してから、1回だけ Sentry に送り、最初の失敗を投げる
    public func exportNutrition() async throws {
        let authorized = try await healthStore.writeAuthorizedNutrients()
        guard !authorized.isEmpty else { return }
        let changes = try await HealthDishChanges(store: store)
        var firstFailure: (any Error)?
        for dishId in changes.writtenDishIdsToDelete {
            do {
                try await healthStore.deleteNutrition(syncId: dishId)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                firstFailure = firstFailure ?? error
                continue
            }
            try await writingCache { try await store.unmarkDishWrittenToHealth(dishId: dishId) }
        }
        for toWrite in changes.dishesToWrite {
            let contents = toWrite.contents
            // 書く値が1つも無い料理は書かない
            guard
                let write = HealthNutritionWrite(
                    dish: contents, of: toWrite.meal, authorized: authorized)
            else {
                continue
            }
            do {
                try await healthStore.writeNutrition(write)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                firstFailure = firstFailure ?? error
                continue
            }
            try await writingCache {
                try await store.markDishWrittenToHealth(
                    dishId: contents.dish.id, version: contents.dish.version)
            }
        }
        if let firstFailure {
            if let failure = HandledFailure.reported(firstFailure, as: .healthNutritionWrite) {
                await errorReporting.report(failure)
            }
            throw firstFailure
        }
    }

    private let healthStore: any HealthStore
    private let store: any SyncBox & RecordCacheReading & HealthSyncStoring & HealthDishWriteStoring
    private let ownBundleId: String
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let errorReporting: any ErrorReportingSession

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

    private func reporting<T: Sendable>(
        _ area: HandledFailure,
        _ body: () async throws -> T
    ) async throws -> T {
        do {
            return try await body()
        } catch {
            if let failure = HandledFailure.reported(error, as: area) {
                await errorReporting.report(failure)
            }
            throw error
        }
    }

    private func requestAuthorizationIfNotYetRequested() async throws {
        guard try await healthStore.authorizationRequestStatus() == .notYetRequested else {
            return
        }
        try await healthStore.requestAuthorization()
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

extension HealthSyncEngine: WeightHealthExport {}

extension HealthSyncEngine: NutritionHealthExport {}

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
