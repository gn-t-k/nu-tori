import Foundation
import NuToriCore

/// 許可を求める時機と、読み書きの呼び出しを、画面と同期のあいだでつなぐ
@MainActor final class HealthSyncSession {
    let engine: HealthSyncEngine

    init(
        engine: HealthSyncEngine,
        store: any HealthStore,
        startBackgroundDelivery:
            @escaping @Sendable (@escaping @Sendable () async -> Void) async ->
            Void = { _ in }
    ) {
        self.engine = engine
        self.store = store
        self.startBackgroundDelivery = startBackgroundDelivery
    }

    static func live(
        syncStore: any SyncStore,
        healthStore: any HealthStore,
        startBackgroundDelivery:
            @escaping @Sendable (@escaping @Sendable () async -> Void) async ->
            Void = { _ in }
    ) -> HealthSyncSession {
        HealthSyncSession(
            engine: HealthSyncEngine(
                healthStore: healthStore,
                store: syncStore,
                ownBundleId: Bundle.main.bundleIdentifier ?? "app.nu-tori",
                timeZone: { .current },
                now: { .now }
            ),
            store: healthStore,
            startBackgroundDelivery: startBackgroundDelivery
        )
    }

    func bindWakeHandler(_ handler: @escaping @Sendable () async -> Void) {
        onWake = handler
    }

    /// 許可済みなら同期の前に読み、初回の取得で記録が見つかったらそのあとに許可を求める
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
    private var onWake: (@Sendable () async -> Void)?
    private var didStartDelivery = false

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
        guard !didStartDelivery, await isAlreadyRequested(), let onWake else { return }
        didStartDelivery = true
        await startBackgroundDelivery(onWake)
    }
}
