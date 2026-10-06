import Foundation
import NuToriCore
import Observation

@Observable
final class RootModel {
    private(set) var screen: Screen = .opening
    /// 記録忘れの通知を押して開いたときの着き先。タイムラインが着いたら `noteReminderLanded()` で消す
    private(set) var reminderLanding: ReminderLanding?
    /// 画面が今日と操作した時刻を読む時計
    let clock: DeviceClock
    /// 送り待ちに料理を足す・名前を直す書き込みがある料理。食事のカードで、まだ送れていない料理として見せる
    private(set) var unsentDishIds: Set<UUID> = []
    var rejectedLines: [RejectedLine] {
        guard case .accepting(let rejected) = rejectionAcceptance else { return [] }
        return rejected.lines
    }

    init(
        accountSession: AccountSession,
        recordSync: RecordSync,
        health: HealthSyncSession,
        missedWeightRecordWatch: MissedWeightRecordWatch,
        clock: DeviceClock
    ) {
        self.clock = clock
        self.accountSession = accountSession
        self.recordSync = recordSync
        self.health = health
        self.missedWeightRecordWatch = missedWeightRecordWatch
        recordSync.onDestination = { [weak self] destination in
            self?.replaceScreen(with: destination)
        }
        recordSync.onRejectedWrites = { [weak self] writes in
            self?.noteRejected(writes)
        }
        recordSync.onReplacingRecord = { [weak self] recordId in
            self?.dropRejection(for: recordId)
        }
        recordSync.onUnsentDishIds = { [weak self] unsentDishIds in
            guard self?.unsentDishIds != unsentDishIds else { return }
            self?.unsentDishIds = unsentDishIds
        }
    }

    func open() async {
        do {
            replaceScreen(with: try await accountSession.destinationOnOpen())
        } catch is CancellationError {
            return
        } catch {
            replaceScreen(with: .signIn(.introduction))
        }
        await accountSession.beginObservationIfSignedIn()
        let tapWhileOpening: UUID? =
            switch observationStart {
            case .pending(let tapWhileOpening): tapWhileOpening
            case .begun: nil
            }
        observationStart = .begun
        if let tapWhileOpening {
            Task { await self.openFromReminder(noticeId: tapWhileOpening) }
        }
        await syncIfShowingTimeline()
    }

    /// 記録忘れの通知を押して開いた。ヘルスケアを読み、知らせを出すかを決めてから、
    /// その日の知らせがあればその位置に、無ければ今日のいちばん下に着く
    func openFromReminder(noticeId: UUID) async {
        // 起動して初めて開き終え、観測を始めてから決める。始める前の出来事は送られないため
        switch observationStart {
        case .pending:
            observationStart = .pending(tapWhileOpening: noticeId)
            return
        case .begun:
            break
        }
        switch screen {
        case .loadingTimeline, .timeline:
            await health.importChanges()
            await recordSync.refreshMissedWeightRecordWatch(after: .reminderTapped)
            let hadNotice = await recordSync.hasNotice(id: noticeId)
            reminderLanding = hadNotice ? .notice(id: noticeId) : .timelineEnd
            await accountSession.capture(.missedWeightReminderOpened(hadNotice: hadNotice))
        case .opening, .signIn:
            return
        }
    }

    func noteReminderLanded() {
        reminderLanding = nil
    }

    /// 体重を記録したあと。この端末でまだ通知の許可を求めていなければ、iPhone の画面で求める
    func requestNotificationPermissionAfterWeightRecorded() async {
        switch await missedWeightRecordWatch.requestPermissionIfNotYetRequested() {
        case .granted:
            await accountSession.capture(.notificationPermissionRequested(granted: true))
        case .notGranted:
            await accountSession.capture(.notificationPermissionRequested(granted: false))
        case .alreadyRequested:
            return
        }
    }

    func notificationPermission() async -> NotificationPermission {
        await missedWeightRecordWatch.permission()
    }

    func capture(_ event: ClientUsageEvent) async {
        await accountSession.capture(event)
    }

    /// Apple ID の設定で連携を止めたあと、アプリを終了せずに戻った人にも、サインインの画面を出すため
    func reopenIfSignedIn() async {
        switch screen {
        case .loadingTimeline, .timeline:
            await open()
        case .opening, .signIn:
            return
        }
    }

    func saveWeight(_ write: WeightEntry.Write) async {
        try? await recordSync.save(write)
    }

    /// 撮った写真は、1枚で1つの食事にする。食事の時刻は撮った時刻（付帯情報に無ければ「写真を使用」を押した時刻）
    func recordCapturedMeal(original: Data, exif: PhotoExif, sentAt: Date) async {
        let timeZone = clock.timeZone()
        let photoId = UUID()
        let takenAt = PhotoTakenTime(exif: exif, pickedAt: sentAt, deviceTimeZone: timeZone)
        let draft = MealDraft.captured(
            photoId: photoId, takenAt: takenAt.instant, sentAt: sentAt, deviceTimeZone: timeZone)
        await recordMeals([draft], originals: [photoId: original], entry: .captured)
    }

    /// 選んだ写真を、撮影時刻の近いものごとの食事にまとめて記録する。`pickedAt` は選び終えた時刻
    func recordPickedMeals(originals: [Data], pickedAt: Date) async {
        let timeZone = clock.timeZone()
        let photos = originals.map { (id: UUID(), original: $0) }
        let picked = photos.map { photo in
            PickedPhoto(
                id: photo.id,
                takenTime: PhotoTakenTime(
                    exif: PhotoMetadata.exif(ofImageData: photo.original),
                    pickedAt: pickedAt,
                    deviceTimeZone: timeZone
                )
            )
        }
        // 選ぶ画面は 10 枚までしか選ばせないので、多すぎることは無い
        guard !picked.isEmpty,
            let drafts = try? MealDraft.picked(picked, sentAt: pickedAt, deviceTimeZone: timeZone)
        else {
            return
        }
        await recordMeals(
            drafts,
            originals: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.original) }),
            entry: .picked
        )
    }

    /// 食事を消す。インターネットにつながらなくても、その場でキャッシュとアプリの中の写真から消える。
    /// 消せたら、PostHog に推定の状態と、送ってから消すまでの時間を送る
    func deleteMeal(_ card: MealCard, deletedAt: Date) async {
        do {
            try await recordSync.deleteMeal(id: card.meal.id)
        } catch {
            return
        }
        await accountSession.capture(.mealDeleted(card, at: deletedAt))
    }

    /// 食事の画面で撮った時刻を直す。インターネットにつながらなくても、その場で1日の丸と日のまとめが直した日に移る。
    /// 直せたら、PostHog に直した回数を送る（時刻は送らない）
    func correctMealTime(_ card: MealCard, eatenAt: Date) async {
        do {
            try await recordSync.correctMealTime(mealId: card.meal.id, eatenAt: eatenAt)
        } catch {
            return
        }
        await accountSession.capture(.mealTimeCorrected)
    }

    /// 料理の画面で料理の名前を直す。インターネットにつながらなくても、その場で直した名前になる。
    /// 送ったら、PostHog に直した回数を送る（名前は送らない）。空の名前と今と同じ名前は送らない
    func renameDish(_ dish: Dish, to typedName: String) async {
        guard let renamed = try? await recordSync.renameDish(id: dish.id, to: typedName),
            renamed != dish
        else { return }
        await accountSession.capture(.dishCorrected)
    }

    /// 料理の画面で料理の量を直す。その場で材料の量と kcal・栄養の内訳が変わる。送ったら、PostHog に直した回数を送る（量は送らない）
    func correctDishQuantity(_ dish: Dish, to value: Double) async {
        guard let corrected = try? await recordSync.correctDishQuantity(id: dish.id, to: value),
            corrected != dish
        else { return }
        await accountSession.capture(.dishCorrected)
    }

    /// 料理の画面で材料の量を直す。その場で kcal と栄養の内訳が変わる。送ったら、PostHog に料理を直した回数を送る（量は送らない）
    func correctIngredientQuantity(_ ingredient: Ingredient, to quantity: Double) async {
        guard
            let corrected = try? await recordSync.correctIngredientQuantity(
                id: ingredient.id, to: quantity),
            corrected != ingredient
        else { return }
        await accountSession.capture(.dishCorrected)
    }

    /// 料理を消す（食事の画面で左へ送った、料理の画面の「この料理を削除」。最後の1品でないとき）。
    /// インターネットにつながらなくても、その場で消える。消せたら、PostHog に消した回数を送る（名前は送らない）
    func deleteDish(_ dish: Dish) async {
        do {
            try await recordSync.deleteDish(id: dish.id)
        } catch {
            return
        }
        await accountSession.capture(.dishDeleted)
    }

    /// 食事の画面の「料理を足す」。インターネットにつながらなくても、その場で料理の行が出る。
    /// 足したら、PostHog に足した回数を送る（名前は送らない）。空の名前は足さない
    func addDish(named typedName: String, to card: MealCard) async {
        guard (try? await recordSync.addDish(named: typedName, toMeal: card.meal.id)) != nil
        else { return }
        await accountSession.capture(.dishAdded)
    }

    /// カードに出す写真のファイル。この端末に無ければ取りに行く。取れなければ nil
    func mealPhotoFile(mealId: UUID, photoId: UUID) async -> URL? {
        await recordSync.mealPhotos.photoFile(mealId: mealId, photoId: photoId)
    }

    func holdsMealOriginals(_ mealId: UUID) async -> Bool {
        await recordSync.mealPhotos.holdsOriginals(ofMeal: mealId)
    }

    func prepareWeightEntry() async {
        await health.prepareForFirstWeightEntry()
        // ヘルスケアから今日の体重を読み込んでいれば、知らせに答える
        await recordSync.refreshMissedWeightRecordWatch(after: .weightEntryOpening)
    }

    func noteAppBackgrounded() {
        rejectionAcceptance = .ignoring
        recordSync.stopWaitingForNoticeTime()
    }

    func noteAppActive() {
        switch rejectionAcceptance {
        case .ignoring:
            rejectionAcceptance = .accepting(RejectedLines())
        case .accepting:
            break
        }
    }

    func signedInAccountId() async -> String? {
        await accountSession.signedInAccountId()
    }

    func turnOnUsageData() async {
        try? await recordSync.turnOnUsageData()
    }

    func turnOffUsageData() async {
        try? await recordSync.turnOffUsageData()
    }

    func deleteAccount() async -> AccountDeletionFailure? {
        let outcome: AccountSession.DeleteAccountOutcome
        do {
            outcome = try await accountSession.deleteAccount()
        } catch is CancellationError {
            return nil
        } catch {
            // 投げるのは端末の記録を消すところだけで、サーバーではもう消えているか、セッションが切れている
            replaceScreen(with: .signIn(.introduction))
            return nil
        }
        switch outcome {
        case .deleted:
            replaceScreen(with: .signIn(.introduction))
            return nil
        case .signInRequired(let destination):
            replaceScreen(with: destination)
            return nil
        case .unreachable:
            return .unreachable
        case .retryLater:
            return .retryLater
        }
    }

    func signIn(with result: AppleSignInResult) async {
        guard case .signIn(let prompt, _) = screen else { return }
        switch result {
        case .cancelled:
            screen = .signIn(prompt, .ready)
        case .failed:
            screen = .signIn(prompt, .failed(.other))
        case .authorized(let credential):
            screen = .signIn(prompt, .signingIn)
            screen = await signInOutcomeScreen(prompt: prompt, credential: credential)
            await accountSession.beginObservationIfSignedIn()
            await syncIfShowingTimeline()
        }
    }

    enum Screen: Equatable {
        case opening
        case signIn(SignInDestination.Prompt, SignInStatus)
        case loadingTimeline
        case timeline

        init(_ destination: SignInDestination) {
            switch destination {
            case .signIn(let prompt): self = .signIn(prompt, .ready)
            case .loadingTimeline: self = .loadingTimeline
            case .timeline: self = .timeline
            }
        }
    }

    private let accountSession: AccountSession
    private let recordSync: RecordSync
    private let health: HealthSyncSession
    private let missedWeightRecordWatch: MissedWeightRecordWatch
    private var observationStart = ObservationStart.pending(tapWhileOpening: nil)
    private var rejectionAcceptance = RejectionAcceptance.accepting(RejectedLines())

    /// 起動して初めて開き終え、観測を始めたか
    private enum ObservationStart {
        /// 開いている途中で、まだ始めていない。`tapWhileOpening` は、その途中に押された記録忘れの通知の ID
        case pending(tapWhileOpening: UUID?)
        case begun
    }

    private enum RejectionAcceptance {
        case accepting(RejectedLines)
        case ignoring
    }

    private func replaceScreen(with destination: SignInDestination) {
        switch destination {
        case .signIn:
            // 受け付けなかった1行は前のアカウントの記録なので、次にサインインしたアカウントに出さない
            discardRejectedLines()
            // サインアウトとアカウントの削除で、予約した通知と通知センターに残った通知を外し、前の時刻で待たない
            recordSync.stopWaitingForNoticeTime()
            Task { [missedWeightRecordWatch] in await missedWeightRecordWatch.removeAll() }
        case .loadingTimeline, .timeline:
            break
        }
        screen = Screen(destination)
    }

    private func dropRejection(for recordId: UUID) {
        switch rejectionAcceptance {
        case .ignoring:
            break
        case .accepting(var rejected):
            rejected.remove(recordId: recordId)
            rejectionAcceptance = .accepting(rejected)
        }
    }

    /// 受け付けない状態のあいだにサインインの画面に戻っても、次のサインインからは受け付ける
    private func discardRejectedLines() {
        switch rejectionAcceptance {
        case .ignoring:
            rejectionAcceptance = .accepting(RejectedLines())
        case .accepting(var rejected):
            rejected.removeAll()
            rejectionAcceptance = .accepting(rejected)
        }
    }

    private func noteRejected(_ writes: [RejectedWrite]) {
        switch rejectionAcceptance {
        case .ignoring:
            break
        case .accepting(var rejected):
            rejected.add(writes)
            rejectionAcceptance = .accepting(rejected)
        }
    }

    private func recordMeals(
        _ drafts: [MealDraft], originals: [UUID: Data], entry: MealDraft.Entry
    ) async {
        guard let meals = try? await recordSync.recordMeals(drafts, originals: originals),
            !meals.isEmpty
        else {
            return
        }
        await accountSession.capture(
            .mealRecorded(entry: entry, photoCount: originals.count, mealCount: meals.count))
        // 撮る・選ぶ画面が閉じてタイムラインに戻ってから、栄養の書き込みの許可を求める
        await health.requestNutritionAuthorizationAfterMealRecorded()
    }

    private func syncIfShowingTimeline() async {
        switch screen {
        case .loadingTimeline, .timeline:
            await recordSync.resendPendingPhotos()
            await health.aroundTimelineSync {
                _ = try await self.recordSync.sync()
            }
            // 送れなくても、同期の前に記録忘れの見張りが決めて返した時刻を待つ
            recordSync.startWaitingForNoticeTime()
        case .opening, .signIn:
            return
        }
    }

    private func signInOutcomeScreen(
        prompt: SignInDestination.Prompt,
        credential: AppleSignInCredential
    ) async -> Screen {
        do {
            switch try await accountSession.signIn(with: credential) {
            case .signedIn(let destination): return Screen(destination)
            case .failed(let reason): return .signIn(prompt, .failed(reason))
            }
        } catch {
            return .signIn(prompt, .failed(.other))
        }
    }
}
