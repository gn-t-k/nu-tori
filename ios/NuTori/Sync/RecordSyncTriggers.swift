import BackgroundTasks
import Foundation
import Network
import NuToriCore

/// バックグラウンド更新で起こされたとき、電波が戻ったとき、端末の日付かタイムゾーンが変わったときを、同期の段取りに知らせる
final class RecordSyncTriggers {
    /// Info.plist の `BGTaskSchedulerPermittedIdentifiers` と同じ
    static let refreshTaskIdentifier = "app.nu-tori.refresh"

    init(recordSync: RecordSync, health: HealthSyncSession) {
        self.recordSync = recordSync
        self.health = health
    }

    func registerAndWatch() {
        if !didRegisterRefresh {
            didRegisterRefresh = true
            // この閉包は MainActor に隔離されるので、メインのキューで呼ばせる。nil だとほかのキューで呼ばれ、隔離の確かめで落ちる
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: Self.refreshTaskIdentifier,
                using: .main
            ) { [weak self] task in
                guard let refresh = task as? BGAppRefreshTask else { return }
                let job = Task { @MainActor in
                    await self?.handle(refresh)
                }
                // 期限切れはどのキューで呼ばれるか決まっていないので、MainActor に隔離しない
                refresh.expirationHandler = { @Sendable in
                    job.cancel()
                }
            }
        }
        watchNetwork()
        watchClock()
        scheduleBackgroundRefresh()
        Task { await health.startDeliveryIfNeeded() }
    }

    private let recordSync: RecordSync
    private let health: HealthSyncSession
    private var didRegisterRefresh = false
    private var networkMonitor: NWPathMonitor?
    private var networkWasUnavailable = false
    private var clockObservers: [any NSObjectProtocol] = []

    private func handle(_ task: BGAppRefreshTask) async {
        scheduleBackgroundRefresh()
        task.setTaskCompleted(success: await recordSync.refreshInBackground())
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        // システムがこれより早く起こすことはほぼ無い。システムが端末の本当の時計と比べるので、時計を通さずに今から数える
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

    /// 端末のタイムゾーンが変わったとき、日付が変わったときに、記録忘れの通知を置き直し、開いていれば知らせを出す時刻を待ち直す
    private func watchClock() {
        guard clockObservers.isEmpty else { return }
        clockObservers = [Notification.Name.NSSystemTimeZoneDidChange, .NSCalendarDayChanged].map {
            NotificationCenter.default.addObserver(forName: $0, object: nil, queue: .main) {
                [recordSync] _ in
                Task { await recordSync.refreshMissedWeightRecordWatch(after: .clockChanged) }
            }
        }
    }

    private func networkChanged(satisfied: Bool) {
        if satisfied && networkWasUnavailable {
            Task { [recordSync] in _ = try? await recordSync.sync() }
        }
        networkWasUnavailable = !satisfied
    }
}
