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
    /// 送り待ちに料理を足す・名前を直す書き込みがある料理が変わりうるとき（料理を直した・消した、同期した）に、読み直して知らせる。
    /// 送り待ちはキャッシュと別の置き場で `@Query` で読めないので、ここから渡す
    var onUnsentDishIds: (Set<UUID>) -> Void = { _ in }

    func save(_ write: WeightEntry.Write) async throws {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        switch write {
        case .create:
            break
        case .correct(let record):
            onReplacingRecord(record.id)
        }
        let record = try await engineForThisDevice(accountId: accountId).save(write)
        // 積んだ答えは、このあとの同期で送る
        _ = await noteToMissedWeightRecordWatch(after: .weightRecorded)
        await health.export(record)
        _ = try await syncAfterInFlight()
    }

    /// 記録忘れの見張りに出来事を知らせる。知らせの書き込みを積んだら、裏で送る。サインインしていなければ何もしない
    func refreshMissedWeightRecordWatch(after event: MissedWeightRecordWatch.Event) async {
        guard await hasSession(), await signedInAccountId() != nil else { return }
        if await noteToMissedWeightRecordWatch(after: event) {
            syncInBackground()
        }
    }

    /// 開いているあいだ、記録忘れの見張りに次に知らせを出すかを決める時刻を聞いて待ち、来たら決める。
    /// 見張りに出来事を知らせるたびに（日付やタイムゾーンが変わった、いつもの時刻が届いた、など）聞き直して待ち直す
    func startWaitingForNoticeTime() {
        stopWaitingForNoticeTime()
        let now = clock.now
        noticeTimer = .waiting(
            Task { [weak self, missedWeightRecordWatch] in
                // サインアウトのあとは、見張りが時刻を忘れているので待たない
                guard let noticeTime = await missedWeightRecordWatch.nextNoticeTime() else {
                    return
                }
                do {
                    try await Task.sleep(for: .seconds(max(0, noticeTime.timeIntervalSince(now()))))
                } catch {
                    // 待ち直すか、裏へ回って取り消した
                    return
                }
                // 決めたあとに見張りに次の時刻を聞き直して、待ち直す
                await self?.refreshMissedWeightRecordWatch(after: .noticeTimeReached)
            })
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

    /// 食事を記録したあと、食事の写真を送り終えたあと、料理を足した・名前を直したあと。
    /// 送り待ちを送り、送り終えたら、推定中の食事か料理があるあいだ裏で取りに行く
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

    /// 食事の撮った時刻を直す。電波が無くても、その場でキャッシュに当たる。直す書き込みは送り待ちに並ぶ
    func correctMealTime(mealId: UUID, eatenAt: Date) async throws {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        onReplacingRecord(mealId)
        try await engineForThisDevice(accountId: accountId).correctMealTime(
            mealId: mealId, eatenAt: eatenAt)
        syncInBackground()
    }

    /// 電波が無くても、その場でキャッシュとアプリの中の写真から消える。消す書き込みは送り待ちに並ぶ
    func deleteMeal(id mealId: UUID) async throws {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        try await engineForThisDevice(accountId: accountId).deleteMeal(id: mealId)
        syncInBackground()
    }

    /// 料理の名前を直す。電波が無くても、その場でキャッシュに当たる。直す書き込みは送り待ちに並び、送れたらサーバーが推定し直しを始める。
    /// 返すのはキャッシュの今の料理（空の名前と今と同じ名前は送らず、前の料理）。サインインしていなければ nil
    func renameDish(id dishId: UUID, to typedName: String) async throws -> Dish? {
        guard await hasSession(), let accountId = await signedInAccountId() else { return nil }
        onReplacingRecord(dishId)
        let engine = engineForThisDevice(accountId: accountId)
        let dish = try await engine.renameDish(id: dishId, to: typedName)
        await publishUnsentDishIds(engine)
        // 送れたら、推定し直しを待つあいだ数秒おきに取りに行く
        Task { await self.followEstimationAfterSending() }
        return dish
    }

    /// 食事に料理を足す。電波が無くても、その場でキャッシュに入る。作る書き込みは送り待ちに並び、送れたらサーバーが推定し直しを始める。
    /// 返すのは足した料理（空の名前は足さず nil）。サインインしていなければ nil
    func addDish(named typedName: String, toMeal mealId: UUID) async throws -> Dish? {
        guard await hasSession(), let accountId = await signedInAccountId() else { return nil }
        let engine = engineForThisDevice(accountId: accountId)
        guard let dish = try await engine.addDish(named: typedName, toMeal: mealId) else {
            return nil
        }
        await publishUnsentDishIds(engine)
        Task { await self.followEstimationAfterSending() }
        return dish
    }

    /// 料理の量を直す。材料の量も同じ割合で変わる。返すのはキャッシュの今の料理。サインインしていなければ nil
    func correctDishQuantity(id dishId: UUID, to value: Double) async throws -> Dish? {
        guard await hasSession(), let accountId = await signedInAccountId() else { return nil }
        onReplacingRecord(dishId)
        let dish = try await engineForThisDevice(accountId: accountId).correctDishQuantity(
            id: dishId, to: value)
        syncInBackground()
        return dish
    }

    /// 材料の量を直す。返すのはキャッシュの今の材料。サインインしていなければ nil
    func correctIngredientQuantity(id ingredientId: UUID, to quantity: Double) async throws
        -> Ingredient?
    {
        guard await hasSession(), let accountId = await signedInAccountId() else { return nil }
        onReplacingRecord(ingredientId)
        let ingredient = try await engineForThisDevice(accountId: accountId)
            .correctIngredientQuantity(id: ingredientId, to: quantity)
        syncInBackground()
        return ingredient
    }

    /// 料理を消す（最後の1品でないとき）。電波が無くても、その場でキャッシュから消える。消す書き込みは送り待ちに並ぶ
    func deleteDish(id dishId: UUID) async throws {
        guard await hasSession(), let accountId = await signedInAccountId() else { return }
        onReplacingRecord(dishId)
        let engine = engineForThisDevice(accountId: accountId)
        try await engine.deleteDish(id: dishId)
        await publishUnsentDishIds(engine)
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

    func importHealthAndSendPending() async throws {
        await health.importChanges()
        // 送れなくても、取り込んだ体重記録で置き直す
        await refreshMissedWeightRecordWatch(after: .healthImported)
        _ = try await sync()
    }

    /// バックグラウンドの更新で起こされたとき。送れたかを返す
    func refreshInBackground() async -> Bool {
        do {
            try await importHealthAndSendPending()
            return true
        } catch {
            return false
        }
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
        missedWeightRecordWatch: MissedWeightRecordWatch,
        clock: DeviceClock
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
        self.missedWeightRecordWatch = missedWeightRecordWatch
        self.clock = clock
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
    private let missedWeightRecordWatch: MissedWeightRecordWatch
    private let clock: DeviceClock
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

    /// 待っていたら次の時刻を聞き直して待ち直し、知らせの書き込みを積んだかを返す。送るかは呼び出し側が決める
    private func noteToMissedWeightRecordWatch(
        after event: MissedWeightRecordWatch.Event
    ) async -> Bool {
        let enqueued = await missedWeightRecordWatch.refresh(after: event)
        switch noticeTimer {
        case .stopped:
            break
        case .waiting:
            startWaitingForNoticeTime()
        }
        return enqueued
    }

    private func syncInBackground() {
        Task { _ = try? await self.syncAfterInFlight() }
    }

    /// 送ってからの経過は、`clock`（UI テストでは止める）ではなく単調な時計で測る。止めた時計では1分の締め切りが来ないため
    private func followEstimationInBackground(sentAt: ContinuousClock.Instant) {
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
        task.setTaskCompleted(success: await refreshInBackground())
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
                [weak self] _ in
                Task { @MainActor in
                    await self?.refreshMissedWeightRecordWatch(after: .clockChanged)
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
            await errorReporting.report(failure, cause: nil)
        }
        let completedBefore = try await store.syncState()?.hasCompletedInitialPull ?? false
        if !completedBefore, initialPullStartedAt == nil {
            initialPullStartedAt = clock.now()
        }
        let startedAt = initialPullStartedAt ?? clock.now()
        // 出した知らせと答えは、この同期で送る
        _ = await noteToMissedWeightRecordWatch(after: .syncStarting)
        let result: SyncResult
        do {
            result = try await engineForThisDevice(accountId: accountId).sync()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await publishUnsentDishIds(engineForThisDevice(accountId: accountId))
            await accountSession.noteInitialPull(.unfinished)
            throw error
        }
        await publishUnsentDishIds(engineForThisDevice(accountId: accountId))
        let completedAfter = try await store.syncState()?.hasCompletedInitialPull ?? false
        await accountSession.noteInitialPull(
            AccountSession.initialPullNotice(
                completedBefore: completedBefore,
                completedAfter: completedAfter,
                ending: result.ending,
                startedAt: startedAt,
                endedAt: clock.now()
            )
        )
        if completedAfter {
            initialPullStartedAt = nil
        }
        // 答えは次の同期で送る（ここで送り直すと、受け付けられないときに繰り返すため）
        _ = await noteToMissedWeightRecordWatch(after: .synced)
        if !result.rejectedWrites.isEmpty {
            onRejectedWrites(result.rejectedWrites)
        }
        onDestination(try await accountSession.destination(afterSync: result))
        return result
    }

    /// 読めなければ知らせない（前に知らせた料理のまま見せる）
    private func publishUnsentDishIds(_ engine: SyncEngine) async {
        guard let unsentDishIds = try? await engine.unsentDishIds() else { return }
        onUnsentDishIds(unsentDishIds)
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
            timeZone: clock.timeZone,
            now: clock.now,
            readableKinds: AppRecordKinds.registry.names,
            errorReporting: errorReporting,
            weightHealthExport: health.engine,
            nutritionHealthExport: health.engine,
            mealPhotos: mealPhotos
        )
    }
}
