import NuToriCore

extension HealthSyncSession {
    static func live(
        syncStore: any SyncBox & RecordCacheReading & HealthSyncStoring & HealthDishWriteStoring,
        healthStore: any HealthStore,
        errorReporting: any ErrorReportingSession,
        startBackgroundDelivery:
            @escaping @Sendable (@escaping @Sendable () async -> Void) async ->
            Void,
        clock: DeviceClock
    ) -> HealthSyncSession {
        HealthSyncSession(
            engine: HealthSyncEngine(
                healthStore: healthStore,
                store: syncStore,
                ownBundleId: OwnBundleId.value,
                timeZone: clock.timeZone,
                now: clock.now,
                errorReporting: errorReporting
            ),
            store: healthStore,
            startBackgroundDelivery: startBackgroundDelivery
        )
    }
}
