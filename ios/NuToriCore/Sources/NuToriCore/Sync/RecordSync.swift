public import Foundation
public import NuToriAPI
import Synchronization

/// 送り待ちを送って取りに行く段取り。記録を書いたあと、アプリを開いたとき、電波が戻ったとき、バックグラウンド更新で呼ぶ。
/// 書き込みは同期の働き（`SyncEngine`）が送り待ちを先に保存してからキャッシュに当て（ADR-0022）、ここはそのあとに見え方を知らせて送る
public actor RecordSync {
    /// アプリの中の食事の写真と写真の送り残し。画面は `photoFile(mealId:photoId:)` で写真を読む
    public nonisolated let mealPhotos: MealPhotos

    /// - Parameters:
    ///   - watchReply: 見守る要求につなぐ（`NuToriAPIClient.watchReply(sentTextId:)`）
    ///   - importHealthChanges: ヘルスケアの体重を取り込む。許可をまだ求めていなければ何もしない
    ///   - takeStoreRecoveries: 置き場を開くときに対処した失敗。渡したら空になる
    public init(
        store: any SyncBox & RecordCacheReading,
        engines: any SyncEngineSource,
        clock: RecordSyncClock,
        watchReply: @escaping @Sendable (UUID) async throws -> NuToriAPIClient.WatchReplyResult,
        reflection: any RecordSyncReflection,
        accountSession: AccountSession,
        missedWeightRecordWatch: MissedWeightRecordWatch,
        mealPhotos: MealPhotos,
        errorReporting: any ErrorReportingSession,
        weightHealthExport: any WeightHealthExport,
        importHealthChanges: @escaping @Sendable () async -> Void,
        takeStoreRecoveries: @escaping @Sendable () -> [HandledFailure]
    ) {
        self.store = store
        self.engines = engines
        self.clock = clock
        self.watchReply = watchReply
        self.reflection = reflection
        self.accountSession = accountSession
        self.missedWeightRecordWatch = missedWeightRecordWatch
        self.mealPhotos = mealPhotos
        self.errorReporting = errorReporting
        self.weightHealthExport = weightHealthExport
        self.importHealthChanges = importHealthChanges
        self.takeStoreRecoveries = takeStoreRecoveries
    }

    /// 同時に呼ばれたら、動いている1回にまとめる。サインインしていなければ nil
    public func sync() async throws -> SyncResult? {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task {
            // 待っている側が起きる前に空ける。終わった1回を待っていた `syncAfterInFlight` が、終わった結果を受け取って送り直さないことがあるため
            defer { self.inFlight = nil }
            return try await self.runSync()
        }
        inFlight = task
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    public func save(_ write: WeightEntry.Write) async throws {
        guard let engine = await engineIfSignedIn() else { return }
        switch write {
        case .create:
            break
        case .correct(let record):
            await reflection.recordReplacing(id: record.id)
        }
        let record = try await engine.save(write)
        await publishFromPending(engine)
        // 積んだ答えは、このあとの同期で送る
        _ = await noteToMissedWeightRecordWatch(after: .weightRecorded)
        try? await weightHealthExport.exportWeightRecord(record)
        _ = try await syncAfterInFlight()
    }

    /// 記録忘れの見張りに出来事を知らせる。知らせの書き込みを積んだら、裏で送る。サインインしていなければ何もしない
    public func refreshMissedWeightRecordWatch(after event: MissedWeightRecordWatch.Event) async {
        guard await engines.hasSession(), await engines.signedInAccountId() != nil else { return }
        if await noteToMissedWeightRecordWatch(after: event) {
            syncInBackground()
        }
    }

    /// 開いているあいだ、記録忘れの見張りに次に知らせを出すかを決める時刻を聞いて待ち、来たら決める。
    /// 見張りに出来事を知らせるたびに（日付やタイムゾーンが変わった、いつもの時刻が届いた、など）聞き直して待ち直す。
    /// 始めるのも取り消すのも、段取りの順番を待たずにその場で効く。裏へ回ったあとに、前の待ちで見張りを動かさないため
    public nonisolated func startWaitingForNoticeTime() {
        let replaced = noticeTimer.withLock { timer in
            defer { timer = .waiting(waitForNoticeTime()) }
            return timer
        }
        replaced.cancel()
    }

    /// 裏へ回ったら待たない。前面に戻ったときに待ち直す
    public nonisolated func stopWaitingForNoticeTime() {
        let stopped = noticeTimer.withLock { timer in
            defer { timer = .stopped }
            return timer
        }
        stopped.cancel()
    }

    /// キャッシュにその ID の知らせがあるか（答えていても）
    public func hasNotice(id noticeId: UUID) async -> Bool {
        let notices = (try? await store.notices()) ?? []
        return notices.contains { $0.id == noticeId }
    }

    /// 1回の撮る・選ぶでできた食事を記録する。`originals` は写真の ID ごとの元の写真で、どの食事の写真もそろっている。
    /// 写真はアプリの中に置いて裏で送り始め、食事の書き込みは送り待ちから裏で送る。送れなかった分は送り待ちに残る。
    /// 同期の往復を待たずに返す（呼び出し側が、タイムラインに戻ってすぐ栄養の許可を求めるため）。
    /// 送れたら、推定中の食事があるあいだ、裏で取りに行く。サインインしていなければ記録せず空。
    /// 記録できなかった食事があれば投げる（それより前の食事は記録してある）
    @discardableResult
    public func recordMeals(_ drafts: [MealDraft], originals: [UUID: Data]) async throws -> [Meal] {
        guard let engine = await engineIfSignedIn() else { return [] }
        var meals: [Meal] = []
        for draft in drafts {
            meals.append(try await engine.recordMeal(draft, originals: originals))
        }
        await publishFromPending(engine)
        Task { await self.followEstimationAfterSending() }
        return meals
    }

    /// 食事を記録したあと、食事の写真を送り終えたあと、料理を足した・名前を直したあと。
    /// 送り待ちを送り、送り終えたら、推定中の食事か料理があるあいだ裏で取りに行く
    public func followEstimationAfterSending() async {
        guard let result = try? await syncAfterInFlight(), result.ending == .finished else {
            return
        }
        followEstimationInBackground(sentAt: clock.monotonicNow())
    }

    /// App スイッチャーで閉じると裏の送信が取り消されるので、開いたときに写真の送り残しを送り直す
    public func resendPendingPhotos() async {
        guard await engines.hasSession() else { return }
        await mealPhotos.resendPendingUploads()
    }

    /// 食事の撮った時刻を直す。電波が無くても、その場でキャッシュに当たる。直す書き込みは送り待ちに並ぶ
    public func correctMealTime(mealId: UUID, eatenAt: Date) async throws {
        guard let engine = await engineIfSignedIn() else { return }
        await reflection.recordReplacing(id: mealId)
        try await engine.correctMealTime(mealId: mealId, eatenAt: eatenAt)
        await publishFromPending(engine)
        syncInBackground()
    }

    /// 電波が無くても、その場でキャッシュとアプリの中の写真から消える。消す書き込みは送り待ちに並ぶ
    public func deleteMeal(id mealId: UUID) async throws {
        guard let engine = await engineIfSignedIn() else { return }
        try await engine.deleteMeal(id: mealId)
        syncInBackground()
    }

    /// 料理の名前を直す。電波が無くても、その場でキャッシュに当たる。直す書き込みは送り待ちに並び、送れたらサーバーが推定し直しを始める。
    /// 返すのはキャッシュの今の料理（空の名前と今と同じ名前は送らず、前の料理）。サインインしていなければ nil
    public func renameDish(id dishId: UUID, to typedName: String) async throws -> Dish? {
        guard let engine = await engineIfSignedIn() else { return nil }
        await reflection.recordReplacing(id: dishId)
        let dish = try await engine.renameDish(id: dishId, to: typedName)
        await publishFromPending(engine)
        // 送れたら、推定し直しを待つあいだ数秒おきに取りに行く
        Task { await self.followEstimationAfterSending() }
        return dish
    }

    /// 食事に料理を足す。電波が無くても、その場でキャッシュに入る。作る書き込みは送り待ちに並び、送れたらサーバーが推定し直しを始める。
    /// 返すのは足した料理（空の名前は足さず nil）。サインインしていなければ nil
    public func addDish(named typedName: String, toMeal mealId: UUID) async throws -> Dish? {
        guard let engine = await engineIfSignedIn() else { return nil }
        guard let dish = try await engine.addDish(named: typedName, toMeal: mealId) else {
            return nil
        }
        await publishFromPending(engine)
        Task { await self.followEstimationAfterSending() }
        return dish
    }

    /// 料理の量を直す。材料の量も同じ割合で変わる。返すのはキャッシュの今の料理。サインインしていなければ nil
    public func correctDishQuantity(id dishId: UUID, to value: Double) async throws -> Dish? {
        guard let engine = await engineIfSignedIn() else { return nil }
        await reflection.recordReplacing(id: dishId)
        let dish = try await engine.correctDishQuantity(id: dishId, to: value)
        await publishFromPending(engine)
        syncInBackground()
        return dish
    }

    /// 材料の量を直す。返すのはキャッシュの今の材料。サインインしていなければ nil
    public func correctIngredientQuantity(id ingredientId: UUID, to quantity: Double) async throws
        -> Ingredient?
    {
        guard let engine = await engineIfSignedIn() else { return nil }
        await reflection.recordReplacing(id: ingredientId)
        let ingredient = try await engine.correctIngredientQuantity(
            id: ingredientId, to: quantity)
        await publishFromPending(engine)
        syncInBackground()
        return ingredient
    }

    /// 料理を消す（最後の1品でないとき）。電波が無くても、その場でキャッシュから消える。消す書き込みは送り待ちに並ぶ
    public func deleteDish(id dishId: UUID) async throws {
        guard let engine = await engineIfSignedIn() else { return }
        await reflection.recordReplacing(id: dishId)
        try await engine.deleteDish(id: dishId)
        await publishFromPending(engine)
        syncInBackground()
    }

    /// 入力欄から文章を送る。電波が無くても、その場でキャッシュに入る。作る書き込みは送り待ちに並ぶ。
    /// 返すのは送った文章（受け付ける範囲の外は送らず nil）。サインインしていなければ nil
    @discardableResult
    public func sendText(_ typedBody: String) async throws -> SentText? {
        guard let engine = await engineIfSignedIn() else { return nil }
        guard let sentText = try await engine.sendText(typedBody) else { return nil }
        await followRepliesAfterWriting(engine)
        return sentText
    }

    /// 文章の食事のカードの「会話として送り直す」。電波が無くても、その場でその文章の食事・料理・材料がキャッシュから消える。
    /// 書き込みは送り待ちに並ぶ
    public func resendAsConversation(sentTextId: UUID) async throws {
        try await resendText(sentTextId: sentTextId) { engine in
            try await engine.resendAsConversation(sentTextId: sentTextId)
        }
    }

    /// 作れなかった・回数切れの1行の「送り直す」。書き込みは送り待ちに並ぶ
    public func resend(sentTextId: UUID) async throws {
        try await resendText(sentTextId: sentTextId) { engine in
            try await engine.resend(sentTextId: sentTextId)
        }
    }

    /// 裏へ回ったとき・サインアウトしたときに、見守る要求をすべて切る。前面に戻って同期を終えたら、つなぎ直す
    public func stopFollowingReplies() async {
        await replyWatches.stopAll()
    }

    /// 送れなかった分は送り待ちに残る
    public func turnOnUsageData() async throws {
        guard let accountId = await engines.signedInAccountId() else { return }
        try await engines.engine(accountId: accountId).setSendsUsageData(true)
        // 始めてよいかは、保存した設定を読んで決める
        await accountSession.beginObservationIfSignedIn()
        syncInBackground()
    }

    /// 送れなかった分は送り待ちに残る
    public func turnOffUsageData() async throws {
        guard let accountId = await engines.signedInAccountId() else { return }
        // オフにした1件は、オフの設定が効くと送れなくなる
        await accountSession.turnOffUsageData()
        do {
            try await engines.engine(accountId: accountId).setSendsUsageData(false)
        } catch {
            // オフにできなかったので、止めた PostHog を始め直す
            await accountSession.beginObservationIfSignedIn()
            throw error
        }
        syncInBackground()
    }

    public func importHealthAndSendPending() async throws {
        await importHealthChanges()
        // 送れなくても、取り込んだ体重記録で置き直す
        await refreshMissedWeightRecordWatch(after: .healthImported)
        _ = try await sync()
    }

    /// バックグラウンドの更新で起こされたとき。送れたかを返す
    public func refreshInBackground() async -> Bool {
        do {
            try await importHealthAndSendPending()
            return true
        } catch {
            return false
        }
    }

    private let store: any SyncBox & RecordCacheReading
    private let engines: any SyncEngineSource
    private let clock: RecordSyncClock
    private let watchReply: @Sendable (UUID) async throws -> NuToriAPIClient.WatchReplyResult
    private let reflection: any RecordSyncReflection
    private let accountSession: AccountSession
    private let missedWeightRecordWatch: MissedWeightRecordWatch
    private let errorReporting: any ErrorReportingSession
    private let weightHealthExport: any WeightHealthExport
    private let importHealthChanges: @Sendable () async -> Void
    private let takeStoreRecoveries: @Sendable () -> [HandledFailure]
    /// 初めての取得を測り始めた時刻。測る前と、終えたあとは無い
    private var initialPullStartedAt: Date?
    private var inFlight: Task<SyncResult?, any Error>?
    /// 段取りの外（画面）からその場で取り消せるよう、actor の状態にせず鍵で守る
    private let noticeTimer = Mutex(NoticeTimer.stopped)
    /// 応答を待つ送った文章ごとの見守る要求。閉じたら取りに行き、届いた返事が途中の返事を置き換える
    private lazy var replyWatches = ReplyWatches(
        watch: watchReply,
        onStreams: { [reflection] streams in await reflection.replyStreamsChanged(streams) },
        onClosed: { [weak self] in await self?.syncAfterReplyWatchClosed() }
    )

    private enum NoticeTimer {
        case stopped
        case waiting(Task<Void, Never>)

        func cancel() {
            switch self {
            case .stopped:
                break
            case .waiting(let task):
                task.cancel()
            }
        }
    }

    private nonisolated func waitForNoticeTime() -> Task<Void, Never> {
        Task { [weak self, missedWeightRecordWatch, clock] in
            // サインアウトのあとは、見張りが時刻を忘れているので待たない
            guard let noticeTime = await missedWeightRecordWatch.nextNoticeTime() else {
                return
            }
            do {
                try await clock.wait(
                    .seconds(max(0, noticeTime.timeIntervalSince(clock.now()))))
            } catch {
                // 待ち直すか、裏へ回って取り消した
                return
            }
            // 決めたあとに見張りに次の時刻を聞き直して、待ち直す
            await self?.refreshMissedWeightRecordWatch(after: .noticeTimeReached)
        }
    }

    /// 待っていたら、次の時刻を聞き直して待ち直す。待つのをやめたあとは、待ち直さない
    private nonisolated func restartWaitingForNoticeTimeIfWaiting() {
        let replaced = noticeTimer.withLock { timer in
            switch timer {
            case .stopped:
                return NoticeTimer.stopped
            case .waiting:
                defer { timer = .waiting(waitForNoticeTime()) }
                return timer
            }
        }
        replaced.cancel()
    }

    private func engineIfSignedIn() async -> SyncEngine? {
        guard await engines.hasSession(), let accountId = await engines.signedInAccountId() else {
            return nil
        }
        return await engines.engine(accountId: accountId)
    }

    /// 待っていたら次の時刻を聞き直して待ち直し、知らせの書き込みを積んだかを返す。送るかは呼び出し側が決める
    private func noteToMissedWeightRecordWatch(
        after event: MissedWeightRecordWatch.Event
    ) async -> Bool {
        let enqueued = await missedWeightRecordWatch.refresh(after: event)
        restartWaitingForNoticeTimeIfWaiting()
        return enqueued
    }

    private func syncAfterReplyWatchClosed() async {
        _ = try? await syncAfterInFlight()
    }

    /// 送り直す書き込みを送り待ちに並べる。サインインしていなければ何もしない
    private func resendText(
        sentTextId: UUID, _ enqueue: (SyncEngine) async throws -> Void
    ) async throws {
        guard let engine = await engineIfSignedIn() else { return }
        await reflection.recordReplacing(id: sentTextId)
        try await enqueue(engine)
        await followRepliesAfterWriting(engine)
    }

    /// 文章の書き込みを送り待ちに並べたあと。まだ届いていない記録としてその場で描き、裏で送って返事を追う
    private func followRepliesAfterWriting(_ engine: SyncEngine) async {
        await publishFromPending(engine)
        Task { await self.followRepliesAfterSending() }
    }

    /// 文章を送った・送り直したあと。送り待ちを送り、送り終えたら、見守る要求がつながっていない応答待ちの文章のために、送ってから1分まで数秒おきに取りに行く
    private func followRepliesAfterSending() async {
        guard let result = try? await syncAfterInFlight(), result.ending == .finished,
            let accountId = await engines.signedInAccountId()
        else { return }
        let engine = await engines.engine(accountId: accountId)
        let sentAt = clock.monotonicNow()
        let followUp = ReplyFollowUp(sentAt: sentAt, now: clock.monotonicNow, wait: clock.wait)
        try? await followUp.run(
            awaiting: { try await engine.sentTextsAwaitingResponse() },
            watching: { await self.replyWatches.connectedSentTextIds },
            sync: { try await self.sync() })
        // 食事と読み分けた文章は文章の食事になり、推定を待つ。送ってから1分まで、推定中の食事があるあいだ取りに行く
        followEstimationInBackground(sentAt: sentAt)
    }

    /// 同期を終えたら、応答を待つ送った文章の見守る要求をつなぎ、応答を待たなくなった文章の途中の返事を捨てる
    private func followReplies(_ engine: SyncEngine) async {
        guard let awaiting = try? await engine.sentTextsAwaitingResponse() else { return }
        await replyWatches.follow(awaiting: awaiting)
    }

    private func syncInBackground() {
        Task { _ = try? await self.syncAfterInFlight() }
    }

    private func followEstimationInBackground(sentAt: ContinuousClock.Instant) {
        let followUp = EstimationFollowUp(
            sentAt: sentAt, cache: store, now: clock.monotonicNow, wait: clock.wait)
        Task { try? await followUp.run { try await self.sync() } }
    }

    /// 開いたときの同期が先に送り待ちを読んでいたら、それが終わってから送り直す
    private func syncAfterInFlight() async throws -> SyncResult? {
        if let inFlight {
            _ = try? await inFlight.value
        }
        return try await sync()
    }

    private func runSync() async throws -> SyncResult? {
        guard let engine = await engineIfSignedIn() else { return nil }
        // 開くときに対処した失敗は、報告の送り先が使えるようになるサインイン後に報告する
        for failure in takeStoreRecoveries() {
            await errorReporting.report(failure, cause: nil)
        }
        let completedBefore = try await store.syncState()?.hasCompletedInitialPull ?? false
        if !completedBefore, initialPullStartedAt == nil {
            initialPullStartedAt = clock.now()
        }
        let startedAt = initialPullStartedAt ?? clock.now()
        // 開いたときに前から残っていた送り待ちと、ヘルスケアから取り込んだ記録を、送り終えるのを待たずに薄く描く
        await publishFromPending(engine)
        // 出した知らせと答えは、この同期で送る
        _ = await noteToMissedWeightRecordWatch(after: .syncStarting)
        let result: SyncResult
        do {
            result = try await engine.sync()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await publishFromPending(engine)
            await accountSession.noteInitialPull(.unfinished)
            throw error
        }
        await publishFromPending(engine)
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
        if result.ending == .finished {
            await followReplies(engine)
        }
        if !result.rejectedWrites.isEmpty {
            await reflection.writesRejected(result.rejectedWrites)
        }
        await reflection.destinationChanged(try await accountSession.destination(afterSync: result))
        return result
    }

    /// 送り待ちから作る見え方（まだ送れていない料理と、まだ届いていない記録）を読み直して知らせる。
    /// 読めなければ知らせない（前に知らせたまま見せる）。
    /// 書き込みを送り待ちに並べたあとは、送るのを待たずに呼ぶ。まだ届いていない記録として、その場で薄く描くため
    private func publishFromPending(_ engine: SyncEngine) async {
        if let unsentDishIds = try? await engine.unsentDishIds() {
            await reflection.unsentDishIdsChanged(unsentDishIds)
        }
        if let undeliveredRecords = try? await engine.undeliveredRecords() {
            await reflection.undeliveredRecordsChanged(undeliveredRecords)
        }
    }
}
