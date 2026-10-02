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
        let engine = engineForThisDevice(accountId: accountId)
        let record = try await engine.save(write)
        // 知らせの中で記録したときも、送るのを待たずに知らせを答えた形にする
        await engine.issueOrRespondToMissedWeightRecordNotices()
        await rescheduleRemindersAndNoticeTime()
        await health.export(record)
        _ = try await syncAfterInFlight()
    }

    /// 体重の知らせを出すか・答えるかを決める。書き込みを並べたら、裏で送る
    func issueOrRespondToNotices() async {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        let engine = engineForThisDevice(accountId: accountId)
        if await engine.issueOrRespondToMissedWeightRecordNotices() {
            syncInBackground()
        }
        await rescheduleRemindersAndNoticeTime()
    }

    /// 体重の知らせに答えるかだけを決め、知らせは出さない（体重のシートを開くとき）。書き込みを並べたら、裏で送る
    func respondToNotices() async {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        let engine = engineForThisDevice(accountId: accountId)
        if await engine.respondToMissedWeightRecordNotices() {
            syncInBackground()
        }
        // ヘルスケアから読み込んだ体重記録で置き直す
        await rescheduleRemindersAndNoticeTime()
    }

    /// 記録忘れの通知を、キャッシュの体重記録といつもの時刻で置き直す。サインインしていなければ置かない
    func rescheduleReminders() async {
        guard await hasSession(), await signedInAccountId() != nil else { return }
        await rescheduleRemindersAndNoticeTime()
    }

    /// 開いているあいだ、次に知らせを出すかを決める時刻を待ち、来たら決める。
    /// 通知を置き直すたびに（日付やタイムゾーンが変わった、いつもの時刻が届いた、など）待ち直す
    func startWaitingForNoticeTime() {
        waitForNoticeTime()
    }

    /// 裏へ回ったら待たない。前面に戻ったときに待ち直す
    func stopWaitingForNoticeTime() {
        switch noticeTimer {
        case .stopped:
            break
        case .waiting(let task):
            task.cancel()
        }
        noticeTimer = .stopped
    }

    /// キャッシュにその ID の知らせがあるか（答えていても）
    func hasNotice(id noticeId: UUID) async -> Bool {
        let notices = (try? await store.notices()) ?? []
        return notices.contains { $0.id == noticeId }
    }

    /// アプリの中の食事の写真と写真の送り残し。画面は `photoFile(mealId:photoId:)` で写真を読む
    let mealPhotos: MealPhotos

    /// 1回の撮る・選ぶでできた食事を記録する。`originals` は写真の ID ごとの元の写真で、どの食事の写真もそろっている。
    /// 写真はアプリの中に置いて裏で送り始め、食事の書き込みは送り待ちから裏で送る。送れなかった分は送り待ちに残る。
    /// 同期の往復を待たずに返す（呼び出し側が、タイムラインに戻ってすぐ栄養の許可を求めるため）。
    /// 送れたら、推定中の食事があるあいだ、裏で取りに行く。サインインしていなければ記録せず空。
    /// 記録できなかった食事があれば投げる（それより前の食事は記録してある）
    @discardableResult
    func recordMeals(_ drafts: [MealDraft], originals: [UUID: Data]) async throws -> [Meal] {
        guard await hasSession(), let accountId = await signedInAccountId() else { return [] }
        let engine = engineForThisDevice(accountId: accountId)
        var meals: [Meal] = []
        for draft in drafts {
            meals.append(try await engine.recordMeal(draft, originals: originals))
        }
        Task { await self.followEstimationAfterSending() }
        return meals
    }

    /// 食事を記録したあとと、食事の写真を送り終えたあと。送り待ちを送り、送り終えたら、推定中の食事があるあいだ裏で取りに行く
    func followEstimationAfterSending() async {
        guard let result = try? await syncAfterInFlight(), result.ending == .finished else {
            return
        }
        followEstimationInBackground(sentAt: .now)
    }

    /// App スイッチャーで閉じると裏の送信が取り消されるので、開いたときに写真の送り残しを送り直す
    func resendPendingPhotos() async {
        guard await hasSession() else { return }
        await mealPhotos.resendPendingUploads()
    }

    /// 電波が無くても、その場でキャッシュとアプリの中の写真から消える。消す書き込みは送り待ちに並ぶ
    func deleteMeal(id mealId: UUID) async throws {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        try await engineForThisDevice(accountId: accountId).deleteMeal(id: mealId)
        syncInBackground()
    }

    /// 送れなかった分は送り待ちに残る
    func turnOnUsageData() async throws {
        guard let accountId = await signedInAccountId() else { return }
        try await engineForThisDevice(accountId: accountId).setSendsUsageData(true)
        // 始めてよいかは、保存した設定を読んで決める
        await accountSession.beginObservationIfSignedIn()
        syncInBackground()
    }

    /// 送れなかった分は送り待ちに残る
    func turnOffUsageData() async throws {
        guard let accountId = await signedInAccountId() else { return }
        // オフにした1件は、オフの設定が効くと送れなくなる
        await accountSession.turnOffUsageData()
        do {
            try await engineForThisDevice(accountId: accountId).setSendsUsageData(false)
        } catch {
            // オフにできなかったので、止めた PostHog を始め直す
            await accountSession.beginObservationIfSignedIn()
            throw error
        }
        syncInBackground()
    }

    func importHealthAndSendPending() async {
        await health.importChanges()
        // 送れなくても、取り込んだ体重記録で置き直す
        await rescheduleReminders()
        _ = try? await sync()
    }

    init(
        store: SwiftDataSyncStore,
        client: NuToriAPIClient,
        accountSession: AccountSession,
        health: HealthSyncSession,
        deviceId: @escaping @MainActor () -> UUID,
        hasSession: @escaping @MainActor () async -> Bool,
        signedInAccountId: @escaping @MainActor () async -> String?,
        errorReporting: any ErrorReportingSession,
        mealPhotos: MealPhotos,
        reminders: MissedWeightRecordReminderScheduler
    ) {
        self.store = store
        self.client = client
        self.accountSession = accountSession
        self.health = health
        self.deviceId = deviceId
        self.hasSession = hasSession
        self.signedInAccountId = signedInAccountId
        self.errorReporting = errorReporting
        self.mealPhotos = mealPhotos
        self.reminders = reminders
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
        watchClock()
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
    private let health: HealthSyncSession
    private let deviceId: @MainActor () -> UUID
    private let hasSession: @MainActor () async -> Bool
    private let signedInAccountId: @MainActor () async -> String?
    private let errorReporting: any ErrorReportingSession
    private let reminders: MissedWeightRecordReminderScheduler
    /// 初めての取得を測り始めた時刻。測る前と、終えたあとは無い
    private var initialPullStartedAt: Date?
    private var didRegisterRefresh = false
    private var inFlight: Task<SyncResult?, any Error>?
    private var networkMonitor: NWPathMonitor?
    private var networkWasUnavailable = false
    private var clockObservers: [any NSObjectProtocol] = []
    private var noticeTimer = NoticeTimer.stopped

    private enum NoticeTimer {
        case stopped
        case waiting(Task<Void, Never>)
    }

    private func rescheduleRemindersAndNoticeTime() async {
        await reminders.reschedule()
        switch noticeTimer {
        case .stopped:
            break
        case .waiting:
            waitForNoticeTime()
        }
    }

    private func waitForNoticeTime() {
        stopWaitingForNoticeTime()
        noticeTimer = .waiting(
            Task { [weak self] in
                guard let noticeTime = await self?.nextNoticeTime() else { return }
                do {
                    try await Task.sleep(for: .seconds(max(0, noticeTime.timeIntervalSinceNow)))
                } catch {
                    // 待ち直すか、裏へ回って取り消した
                    return
                }
                // 決めたあとの置き直しで、次の時刻を待ち直す
                await self?.issueOrRespondToNotices()
            })
    }

    /// 読めなければ、報告して待たない
    private func nextNoticeTime() async -> Date? {
        let usualWeighingTime: UsualWeighingTime?
        let weightRecords: [WeightRecord]
        do {
            usualWeighingTime = try await store.usualWeighingTime()
            weightRecords = try await store.weightRecords()
        } catch {
            if let failure = HandledFailure.reported(error, as: .cacheRead) {
                await errorReporting.report(failure)
            }
            return nil
        }
        return MissedWeightRecordNoticeDecision.nextNoticeTime(
            usualWeighingTime: usualWeighingTime, now: .now, timeZone: .current,
            weightRecords: weightRecords)
    }

    private func syncInBackground() {
        Task { _ = try? await self.syncAfterInFlight() }
    }

    private func followEstimationInBackground(sentAt: Date) {
        let followUp = EstimationFollowUp(
            sentAt: sentAt,
            cache: store,
            now: { .now },
            wait: { try await Task.sleep(for: $0) }
        )
        Task { try? await followUp.run { try await self.sync() } }
    }

    /// 開いたときの同期が先に送り待ちを読んでいたら、それが終わってから送り直す
    private func syncAfterInFlight() async throws -> SyncResult? {
        if let inFlight {
            _ = try? await inFlight.value
        }
        return try await sync()
    }

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

    /// 端末のタイムゾーンが変わったとき、日付が変わったときに、記録忘れの通知を置き直し、開いていれば知らせを出す時刻を待ち直す
    private func watchClock() {
        guard clockObservers.isEmpty else { return }
        clockObservers = [Notification.Name.NSSystemTimeZoneDidChange, .NSCalendarDayChanged].map {
            NotificationCenter.default.addObserver(forName: $0, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in
                    await self?.rescheduleReminders()
                }
            }
        }
    }

    private func networkChanged(satisfied: Bool) {
        if satisfied && networkWasUnavailable {
            Task { try? await self.sync() }
        }
        networkWasUnavailable = !satisfied
    }

    private func runSync() async throws -> SyncResult? {
        guard await hasSession(), let accountId = await signedInAccountId() else { return nil }
        // 開くときに対処した失敗は、報告の送り先が使えるようになるサインイン後に報告する
        for failure in store.takeRecoveries() {
            await errorReporting.report(failure)
        }
        let completedBefore = try await store.syncState()?.hasCompletedInitialPull ?? false
        if !completedBefore, initialPullStartedAt == nil {
            initialPullStartedAt = .now
        }
        let startedAt = initialPullStartedAt ?? .now
        let engine = engineForThisDevice(accountId: accountId)
        // ヘルスケアから取り込んだあとの体重記録で決め、出した知らせと答えをこの同期で送る
        await engine.issueOrRespondToMissedWeightRecordNotices()
        let result: SyncResult
        do {
            result = try await engine.sync()
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
        // 届いた体重記録で答える。答えは次の同期で送る（ここで送り直すと、受け付けられないときに繰り返すため）
        await engine.issueOrRespondToMissedWeightRecordNotices()
        // 届いた体重記録といつもの時刻で置き直す
        await rescheduleRemindersAndNoticeTime()
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
            readableKinds: AppRecordKinds.registry.names,
            errorReporting: errorReporting,
            weightHealthExport: health.engine,
            nutritionHealthExport: health.engine,
            mealPhotos: mealPhotos
        )
    }
}
