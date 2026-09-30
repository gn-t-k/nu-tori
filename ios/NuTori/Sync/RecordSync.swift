import BackgroundTasks
import Foundation
import Network
import NuToriAPI
import NuToriCore

/// アプリを開いたとき、電波が戻ったとき、バックグラウンド更新で、送り待ちを送って取りに行く
@MainActor final class RecordSync {
    /// Info.plist の `BGTaskSchedulerPermittedIdentifiers` と同じ
    static let refreshTaskIdentifier = "app.nu-tori.refresh"

    var onDestination: (SignInDestination) -> Void = { _ in }
    var onRejectedWrites: ([RejectedWrite]) -> Void = { _ in }
    var onReplacingRecord: (UUID) -> Void = { _ in }

    func save(_ write: WeightEntry.Write) async throws {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        switch write {
        case .create:
            break
        case .correct(let record):
            onReplacingRecord(record.id)
        }
        try await engineForThisDevice(accountId: accountId).save(write)
        // 開いたときの同期が先に送り待ちを読んでいたら、それが終わってから送り直す
        if let inFlight {
            _ = try? await inFlight.value
        }
        _ = try await sync()
    }

    init(
        store: SwiftDataSyncStore,
        client: NuToriAPIClient,
        accountSession: AccountSession,
        deviceId: @escaping @MainActor () -> UUID,
        hasSession: @escaping @MainActor () async -> Bool,
        signedInAccountId: @escaping @MainActor () async -> String?,
        errorReporting: any ErrorReportingSession
    ) {
        self.store = store
        self.client = client
        self.accountSession = accountSession
        self.deviceId = deviceId
        self.hasSession = hasSession
        self.signedInAccountId = signedInAccountId
        self.errorReporting = errorReporting
    }

    func registerAndWatch() {
        if !didRegisterRefresh {
            didRegisterRefresh = true
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: Self.refreshTaskIdentifier,
                using: nil
            ) { [weak self] task in
                guard let refresh = task as? BGAppRefreshTask else { return }
                let job = Task { @MainActor in
                    await self?.handle(refresh)
                }
                refresh.expirationHandler = {
                    job.cancel()
                }
            }
        }
        watchNetwork()
        scheduleBackgroundRefresh()
    }

    func sync() async throws -> SyncResult? {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await self.runSync() }
        inFlight = task
        defer { inFlight = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private let store: SwiftDataSyncStore
    private let client: NuToriAPIClient
    private let accountSession: AccountSession
    private let deviceId: @MainActor () -> UUID
    private let hasSession: @MainActor () async -> Bool
    private let signedInAccountId: @MainActor () async -> String?
    private let errorReporting: any ErrorReportingSession
    /// 初めての取得を測り始めた時刻。測る前と、終えたあとは無い
    private var initialPullStartedAt: Date?
    private var didRegisterRefresh = false
    private var inFlight: Task<SyncResult?, any Error>?
    private var networkMonitor: NWPathMonitor?
    private var networkWasUnavailable = false

    private func handle(_ task: BGAppRefreshTask) async {
        scheduleBackgroundRefresh()
        do {
            _ = try await sync()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        // システムがこれより早く起こすことはほぼ無い
        let earliestDelay: TimeInterval = 15 * 60
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestDelay)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func watchNetwork() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in
                self?.networkChanged(satisfied: satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.nu-tori.network-path"))
        networkMonitor = monitor
    }

    private func networkChanged(satisfied: Bool) {
        if satisfied && networkWasUnavailable {
            Task { try? await self.sync() }
        }
        networkWasUnavailable = !satisfied
    }

    private func runSync() async throws -> SyncResult? {
        guard await hasSession(), let accountId = await signedInAccountId() else { return nil }
        let completedBefore = try await store.syncState()?.hasCompletedInitialPull ?? false
        if !completedBefore, initialPullStartedAt == nil {
            initialPullStartedAt = .now
        }
        let startedAt = initialPullStartedAt ?? .now
        let result: SyncResult
        do {
            result = try await engineForThisDevice(accountId: accountId).sync()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await accountSession.noteInitialPull(.unfinished)
            throw error
        }
        let completedAfter = try await store.syncState()?.hasCompletedInitialPull ?? false
        await accountSession.noteInitialPull(
            AccountSession.initialPullNotice(
                completedBefore: completedBefore,
                completedAfter: completedAfter,
                ending: result.ending,
                startedAt: startedAt,
                endedAt: .now
            )
        )
        if completedAfter {
            initialPullStartedAt = nil
        }
        if !result.rejectedWrites.isEmpty {
            onRejectedWrites(result.rejectedWrites)
        }
        onDestination(try await accountSession.destination(afterSync: result))
        return result
    }

    private func engineForThisDevice(accountId: String) -> SyncEngine {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return SyncEngine(
            store: store,
            client: client,
            accountId: accountId,
            device: SyncDevice(
                deviceId: deviceId(),
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                    as? String ?? "0",
                osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            ),
            timeZone: { .current },
            now: { .now },
            readableKindsVersion: SyncEngine.currentReadableKindsVersion,
            errorReporting: errorReporting
        )
    }
}
