import Foundation
import NuToriCore

@MainActor final class HealthSyncSession {
    let engine: HealthSyncEngine

    init(
        engine: HealthSyncEngine,
        store: any HealthStore,
        startBackgroundDelivery:
            @escaping @Sendable (@escaping @Sendable () async -> Void) async ->
            Void
    ) {
        self.engine = engine
        self.store = store
        self.startBackgroundDelivery = startBackgroundDelivery
    }

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
                ownBundleId: Bundle.main.bundleIdentifier ?? "app.nu-tori",
                timeZone: clock.timeZone,
                now: clock.now,
                errorReporting: errorReporting
            ),
            store: healthStore,
            startBackgroundDelivery: startBackgroundDelivery
        )
    }

    func bindWakeHandler(_ handler: @escaping @Sendable () async -> Void) {
        if case .started = delivery { return }
        delivery = .bound(handler)
    }

    func aroundTimelineSync(_ sync: () async throws -> Void) async {
        if await isAlreadyRequested() {
            await importAndExportCached()
        }
        try? await sync()
        if await didJustRequestAfterInitialPull() {
            await importAndExportCached()
            try? await sync()
        }
        await startDeliveryIfNeeded()
    }

    /// 入力欄の「体重」を押した直後。シートを開く前に、許可を求めて最新の値を読む
    func prepareForFirstWeightEntry() async {
        try? await engine.requestAuthorizationOnFirstWeightEntry()
        await importAndExportCached()
        await startDeliveryIfNeeded()
    }

    /// 食事を記録し、カメラや写真を選ぶ画面が閉じてタイムラインに戻ったあと。
    /// この端末で初めてなら、栄養の書き込みの許可を iPhone の画面で求め、閉じたあとにキャッシュの料理を書く
    func requestNutritionAuthorizationAfterMealRecorded() async {
        // 画面が閉じる動きの途中で許可の画面を出すと、出ないことがあるので、閉じ終わるのを待つ
        try? await Task.sleep(for: .milliseconds(600))
        try? await engine.requestNutritionAuthorizationAfterMealRecorded()
    }

    func export(_ record: WeightRecord) async {
        try? await engine.exportWeightRecord(record)
    }

    /// バックグラウンド配信で起こされたとき。許可の画面は出さない
    func importChanges() async {
        guard await isAlreadyRequested() else { return }
        await importAndExportCached()
    }

    private let store: any HealthStore
    private let startBackgroundDelivery:
        @Sendable (@escaping @Sendable () async -> Void) async ->
            Void
    private var delivery = Delivery.unbound

    private enum Delivery {
        case unbound
        case bound(@Sendable () async -> Void)
        case started
    }

    private func isAlreadyRequested() async -> Bool {
        (try? await store.authorizationRequestStatus()) == .alreadyRequested
    }

    private func didJustRequestAfterInitialPull() async -> Bool {
        guard await !isAlreadyRequested() else { return false }
        do {
            try await engine.requestAuthorizationAfterInitialPull()
        } catch {
            return false
        }
        return await isAlreadyRequested()
    }

    private func importAndExportCached() async {
        try? await engine.importChanges()
        try? await engine.exportCachedManualRecordsOnNewWriteAuthorization()
    }

    private func startDeliveryIfNeeded() async {
        guard case .bound(let onWake) = delivery, await isAlreadyRequested() else { return }
        delivery = .started
        await startBackgroundDelivery(onWake)
    }
}
