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
        goalSetupNoticeKeeper: GoalSetupNoticeKeeper,
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
        self.goalSetupNoticeKeeper = goalSetupNoticeKeeper
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

    /// 目標が決まったとき（目標を決める要求の応答を受け取ったとき）。
    /// 知らせが答えていなければ、答えた形にして、答える書き込みを裏で送る。最初の1回だけが答えになる。
    /// サインインしていなければ何もしない
    public func respondToGoalSetupNotice() async {
        guard await engines.hasSession(), await engines.signedInAccountId() != nil else { return }
        if await goalSetupNoticeKeeper.respondIfUnanswered() {
            syncInBackground()
        }
    }

    /// 目標の設定を始めるときの状況。キャッシュに閉じていない目標があれば立て直し
    public func goalSetupStart(today: CalendarDay) async throws -> GoalSetupStart {
        GoalSetupStart(
            goals: try await store.goals(),
            hasWeightRecords: !(try await store.weightRecords()).isEmpty,
            startedOn: try await store.syncState()?.startedOn,
            today: today)
    }

    /// 初めての目標の下見の前。ヘルスケアの体重を取り込み（このとき初めて許可を得た人は全期間分）、送り待ちを送って、
    /// 体重記録の送り待ちが残っていなければ true。電波が無い、同期が止まった、サインインしていなければ false
    public func sendWeightRecordsForGoalSetup() async -> Bool {
        await importHealthChanges()
        guard let result = try? await syncAfterInFlight(), result.ending == .finished,
            let entries = try? await store.pendingEntries()
        else { return false }
        return !entries.contains { $0.kind == .weightRecord }
    }

    /// 足りない値で入れた今の体重を、今日の体重記録にする。体重の記録が1つも無い人だけが入れるので、いつも作る書き込み
    public func recordWeight(kilograms: Double, at instant: Date, in timeZone: TimeZone)
        async throws
    {
        _ = try await perform(
            .saveWeight(.create(kilograms: kilograms, instant: instant, timeZone: timeZone)),
            in: timeZone)
    }

    /// 目標を決める要求の応答の記録を、取りに行った変更と同じ道でキャッシュに当てる。同じ記録があとで同期でも届く
    public func applyGoalDecision(_ changes: [SyncChange]) async throws {
        try await applyOutOfSyncResponse(changes)
    }

    /// サブスクリプションの取引を知らせた要求の応答の記録を、取りに行った変更と同じ道でキャッシュに当てる。同じ記録があとで同期でも届く
    public func applySubscriptionTransactionReport(_ changes: [SyncChange]) async throws {
        try await applyOutOfSyncResponse(changes)
    }

    private func applyOutOfSyncResponse(_ changes: [SyncChange]) async throws {
        try await store.apply(
            SyncBoxResult(
                kindChanges: changes.compactMap { change in
                    change.kindName.map { KindChanges(kind: $0, changes: [change]) }
                }))
    }

    /// キャッシュにその ID の知らせがあるか（答えていても）
    public func hasNotice(id noticeId: UUID) async -> Bool {
        let notices = (try? await store.notices()) ?? []
        return notices.contains { $0.id == noticeId }
    }

    /// キャッシュのサブスクリプションの状態。まだ届いていない、読めないときは nil
    public func subscriptionStatus() async -> SubscriptionStatus? {
        try? await store.subscriptionStatus()
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

    /// ユーザーの編集を書き、`UserEdit.aftermath` の後始末をする。書き込みは送り待ちに並び、送り終えるのを待たずに返す。
    /// `timeZone` は端末の今のタイムゾーン（写真の撮影時刻を読む）。サインインしていなければ書かない。
    /// 書けなかったら投げる（食事の記録では、それより前の食事は記録してある）
    public func perform(_ edit: UserEdit, in timeZone: TimeZone) async throws -> UserEdit.Outcome {
        guard let engine = await engineIfSignedIn() else { return .unwritten }
        let aftermath = edit.aftermath
        if let recordId = aftermath.replacedRecordId {
            await reflection.recordReplacing(id: recordId)
        }
        let written = try await write(edit, with: engine, in: timeZone)
        guard case .written = written.outcome else { return written.outcome }
        await publishFromPending(engine)
        switch aftermath.followUp {
        case .sync:
            syncInBackground()
        case .weightRecorded:
            // 積んだ答えは、このあとの同期で送る
            _ = await noteToMissedWeightRecordWatch(after: .weightRecorded)
            if let record = written.weightRecord {
                try? await weightHealthExport.exportWeightRecord(record)
            }
            syncInBackground()
        case .estimation:
            Task { await self.followEstimationAfterSending() }
        case .replies:
            Task { await self.followRepliesAfterSending() }
        }
        return written.outcome
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
    private let goalSetupNoticeKeeper: GoalSetupNoticeKeeper
    private let errorReporting: any ErrorReportingSession
    private let weightHealthExport: any WeightHealthExport
    private let importHealthChanges: @Sendable () async -> Void
    private let takeStoreRecoveries: @Sendable () -> [HandledFailure]
    /// 初めての取得を測り始めた時刻。測る前と、終えたあとは無い
    private var initialPullStartedAt: Date?
    /// 前の同期の終わりに目標を立てる知らせを出して、送るための同期を裏で始めたか。次の同期の1回が読んで倒す
    private var isSendingIssuedGoalSetupNotice = false
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

    /// 書いた結果と、ヘルスケアに書き出す体重記録
    private struct Written {
        let outcome: UserEdit.Outcome
        var weightRecord: WeightRecord?
    }

    /// 編集を送り待ちとキャッシュに書く。今と同じ値で、書くものが無ければ `.unwritten`
    private func write(_ edit: UserEdit, with engine: SyncEngine, in timeZone: TimeZone)
        async throws -> Written
    {
        switch edit {
        case .saveWeight(let write):
            let record = try await engine.save(write)
            return Written(outcome: .written(recordCount: 1), weightRecord: record)
        case .recordCapturedMeal(let photo, let sentAt):
            let photoId = UUID()
            let takenAt = PhotoTakenTime(
                exif: photo.exif, pickedAt: sentAt, deviceTimeZone: timeZone)
            let draft = MealDraft.captured(
                photoId: photoId, takenAt: takenAt.instant, sentAt: sentAt,
                deviceTimeZone: timeZone)
            return Written(
                outcome: try await recordMeals(
                    [draft], originals: [photoId: photo.data], with: engine))
        case .recordPickedMeals(let photos, let pickedAt):
            let identified = photos.map { (id: UUID(), photo: $0) }
            let picked = identified.map { photo in
                PickedPhoto(
                    id: photo.id,
                    takenTime: PhotoTakenTime(
                        exif: photo.photo.exif, pickedAt: pickedAt, deviceTimeZone: timeZone))
            }
            // 選ぶ画面は 10 枚までしか選ばせないので、多すぎることは無い
            guard !picked.isEmpty,
                let drafts = try? MealDraft.picked(
                    picked, sentAt: pickedAt, deviceTimeZone: timeZone)
            else { return Written(outcome: .unwritten) }
            return Written(
                outcome: try await recordMeals(
                    drafts,
                    originals: Dictionary(
                        uniqueKeysWithValues: identified.map { ($0.id, $0.photo.data) }),
                    with: engine))
        case .correctMealTime(let card, let eatenAt):
            try await engine.correctMealTime(mealId: card.meal.id, eatenAt: eatenAt)
            return Written(outcome: .written(recordCount: 1))
        case .deleteMeal(let card, _):
            try await engine.deleteMeal(id: card.meal.id)
            return Written(outcome: .written(recordCount: 1))
        case .addDish(let typedName, let card):
            let dish = try await engine.addDish(named: typedName, toMeal: card.meal.id)
            return Written(outcome: dish == nil ? .unwritten : .written(recordCount: 1))
        case .renameDish(let dish, let typedName):
            let renamed = try await engine.renameDish(id: dish.id, to: typedName)
            return Written(outcome: renamed == dish ? .unwritten : .written(recordCount: 1))
        case .correctDishQuantity(let dish, let value):
            let corrected = try await engine.correctDishQuantity(id: dish.id, to: value)
            return Written(outcome: corrected == dish ? .unwritten : .written(recordCount: 1))
        case .correctIngredientQuantity(let ingredient, let quantity):
            let corrected = try await engine.correctIngredientQuantity(
                id: ingredient.id, to: quantity)
            return Written(outcome: corrected == ingredient ? .unwritten : .written(recordCount: 1))
        case .deleteDish(let dish):
            try await engine.deleteDish(id: dish.id)
            return Written(outcome: .written(recordCount: 1))
        case .sendText(let draft):
            let sentText = try await engine.sendText(draft.text)
            return Written(outcome: sentText == nil ? .unwritten : .written(recordCount: 1))
        case .resendAsConversation(let sentTextId, _):
            try await engine.resendAsConversation(sentTextId: sentTextId)
            return Written(outcome: .written(recordCount: 1))
        case .resendReply(let sentTextId, _):
            try await engine.resend(sentTextId: sentTextId)
            return Written(outcome: .written(recordCount: 1))
        }
    }

    /// 写真はアプリの中に置いて裏で送り始める。`originals` は写真の ID ごとの元の写真で、どの食事の写真もそろっている
    private func recordMeals(
        _ drafts: [MealDraft], originals: [UUID: Data], with engine: SyncEngine
    ) async throws -> UserEdit.Outcome {
        for draft in drafts {
            _ = try await engine.recordMeal(draft, originals: originals)
        }
        return drafts.isEmpty ? .unwritten : .written(recordCount: drafts.count)
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
        let sendsIssuedGoalSetupNotice = isSendingIssuedGoalSetupNotice
        isSendingIssuedGoalSetupNotice = false
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
            // 取り切ったあとに決める（途中だと、ほかの端末で立てた目標がまだ届いていないことがある）。
            // 出したら、すぐ裏で送る。送り待ちに残すと、サインインし直しの画面が「まだ送っていない記録」があると案内するため。
            // その送るための同期では出さない。作る書き込みが断られて知らせが外れたとき（前の版のサーバー）に、出して送るのを繰り返すため
            if !sendsIssuedGoalSetupNotice, await goalSetupNoticeKeeper.issueIfNoGoal() {
                isSendingIssuedGoalSetupNotice = true
                syncInBackground()
            }
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
        if let appearance = try? await engine.pendingAppearance() {
            await reflection.pendingAppearanceChanged(appearance)
        }
    }
}
