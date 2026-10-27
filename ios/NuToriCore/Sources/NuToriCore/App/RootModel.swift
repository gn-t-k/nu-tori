public import Foundation
public import Observation

/// アプリの流れ。開く・サインインする・サインアウトするで画面を替え、記録忘れの通知から開いた着き先、受け付けなかった1行、
/// 規約への同意のシートを持つ。画面からの編集は `perform(_:)` の1つの口で受ける
@MainActor
@Observable
public final class RootModel {
    public private(set) var screen: Screen = .opening
    /// 記録忘れの通知を押して開いたときの着き先。タイムラインが着いたら `noteReminderLanded()` で消す
    public private(set) var reminderLanding: ReminderLanding?
    /// 画面が今日と操作した時刻を読む時計
    public let clock: DeviceClock
    /// 目標を立てる知らせのカードが広げる、目標の設定の流れ
    public let goalSetup: GoalSetupSession
    /// サブスクリプションを買う・復元する、自動更新を読む。課金画面とアカウントの画面が使う
    public let subscriptionPurchases: SubscriptionPurchases
    /// 送り待ちから作る見え方。まだ届いていない記録はタイムラインで薄く描き、まだ送れていない料理は食事のカードで見せる
    public private(set) var pendingAppearance = PendingAppearance.none
    /// 送った文章の ID ごとの、見守る要求で受け取っている途中の返事。タイムラインで伸ばして描く
    public private(set) var replyStreams: [UUID: ReplyStream] = [:]
    /// 規約への同意のシート。出ているあいだは閉じられず、同意を受け付けられたら消す
    public private(set) var termsAgreementSheet: TermsAgreementSheet?
    public var rejectedLines: [RejectedLine] {
        guard case .accepting(let rejected) = rejectionAcceptance else { return [] }
        return rejected.lines
    }

    public init(
        accountSession: AccountSession,
        recordSync: RecordSync,
        reflector: RecordSyncReflector,
        health: HealthSyncSession,
        missedWeightRecordWatch: MissedWeightRecordWatch,
        goalSetup: GoalSetupSession,
        termsAgreement: TermsAgreementPrompt,
        subscriptionPurchases: SubscriptionPurchases,
        clock: DeviceClock
    ) {
        self.clock = clock
        self.subscriptionPurchases = subscriptionPurchases
        self.termsAgreement = termsAgreement
        self.goalSetup = goalSetup
        self.accountSession = accountSession
        self.recordSync = recordSync
        self.health = health
        self.missedWeightRecordWatch = missedWeightRecordWatch
        reflector.onDestination = { [weak self] destination in
            self?.replaceScreen(with: destination)
        }
        reflector.onRejectedWrites = { [weak self] writes in
            self?.noteRejected(writes)
        }
        reflector.onReplacingRecord = { [weak self] recordId in
            self?.dropRejection(for: recordId)
        }
        reflector.onPendingAppearance = { [weak self] appearance in
            guard self?.pendingAppearance != appearance else { return }
            self?.pendingAppearance = appearance
        }
        reflector.onReplyStreams = { [weak self] streams in
            self?.replyStreams = streams
        }
    }

    public func open() async {
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
        async let reminderOpened: Void = openFromReminderTappedWhileOpening(tapWhileOpening)
        // 同意が要るかは同期を待たずに問う。電波が無くて問えなければ、次に前面に来たときに問い直す
        async let termsAgreementAsked: Void = askTermsAgreementIfShowingTimeline()
        async let unfinishedTransactionsReported: Void =
            reportUnfinishedTransactionsIfShowingTimeline()
        await syncIfShowingTimeline()
        await termsAgreementAsked
        await unfinishedTransactionsReported
        await reminderOpened
    }

    /// 規約への同意のシートを画面に出した
    public func termsAgreementSheetPresented() async {
        await termsAgreement.sheetPresented()
    }

    /// 同意のシートの「同意して続ける」。その場の要求で同意を送り、受け付けられたらシートを消す
    public func agreeToTerms() async -> TermsAgreementPrompt.AgreeOutcome {
        guard let sheet = termsAgreementSheet else { return .agreed }
        let outcome = await termsAgreement.agree(to: sheet)
        if outcome == .agreed, termsAgreementSheet == sheet {
            termsAgreementSheet = nil
        }
        return outcome
    }

    /// 記録忘れの通知を押して開いた。ヘルスケアを読み、知らせを出すかを決めてから、
    /// その日の知らせがあればその位置に、無ければ今日のいちばん下に着く
    public func openFromReminder(noticeId: UUID) async {
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

    public func noteReminderLanded() {
        reminderLanding = nil
    }

    /// 体重を記録したあと。この端末でまだ通知の許可を求めていなければ、iPhone の画面で求める
    public func requestNotificationPermissionAfterWeightRecorded() async {
        switch await missedWeightRecordWatch.requestPermissionIfNotYetRequested() {
        case .granted:
            await accountSession.capture(.notificationPermissionRequested(granted: true))
        case .notGranted:
            await accountSession.capture(.notificationPermissionRequested(granted: false))
        case .alreadyRequested:
            return
        }
    }

    public func notificationPermission() async -> NotificationPermission {
        await missedWeightRecordWatch.permission()
    }

    public func capture(_ event: ClientUsageEvent) async {
        await accountSession.capture(event)
    }

    /// Apple ID の設定で連携を止めたあと、アプリを終了せずに戻った人にも、サインインの画面を出すため
    public func reopenIfSignedIn() async {
        switch screen {
        case .loadingTimeline, .timeline:
            await open()
        case .opening, .signIn:
            return
        }
    }

    /// 画面からの編集を書き、書いたら PostHog に出来事を送る。後始末は `UserEdit.aftermath` に種類ごとに書いてある
    public func perform(_ edit: UserEdit) async {
        guard
            case .written(let recordCount)? = try? await recordSync.perform(
                edit, in: clock.timeZone())
        else { return }
        let aftermath = edit.aftermath
        if let event = aftermath.usage.event(recordCount: recordCount) {
            await accountSession.capture(event)
        }
        if aftermath.requestsNutritionAuthorization {
            // 撮る・選ぶ画面が閉じてタイムラインに戻ってから、栄養の書き込みの許可を求める。
            // 許可の画面が閉じるまで待たずに返し、写真を読んでいるあいだの仮のカードを、食事のカードが出たらすぐ外せるようにする
            Task { await health.requestNutritionAuthorizationAfterMealRecorded() }
        }
    }

    /// カードに出す写真のファイル。この端末に無ければ取りに行く。取れなければ nil
    public func mealPhotoFile(mealId: UUID, photoId: UUID) async -> URL? {
        await recordSync.mealPhotos.photoFile(mealId: mealId, photoId: photoId)
    }

    public func holdsMealOriginals(_ mealId: UUID) async -> Bool {
        await recordSync.mealPhotos.holdsOriginals(ofMeal: mealId)
    }

    public func prepareWeightEntry() async {
        await health.prepareForFirstWeightEntry()
        // ヘルスケアから今日の体重を読み込んでいれば、知らせに答える
        await recordSync.refreshMissedWeightRecordWatch(after: .weightEntryOpening)
    }

    public func noteAppBackgrounded() {
        rejectionAcceptance = .ignoring
        recordSync.stopWaitingForNoticeTime()
        Task { await recordSync.stopFollowingReplies() }
    }

    public func noteAppActive() {
        switch rejectionAcceptance {
        case .ignoring:
            rejectionAcceptance = .accepting(RejectedLines())
        case .accepting:
            break
        }
    }

    public func signedInAccountId() async -> String? {
        await accountSession.signedInAccountId()
    }

    public func turnOnUsageData() async {
        try? await recordSync.turnOnUsageData()
    }

    public func turnOffUsageData() async {
        try? await recordSync.turnOffUsageData()
    }

    public func deleteAccount() async -> AccountDeletionFailure? {
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

    /// サブスクリプション中で自動更新がオンのときだけ返す。返したら、確かめの前に退会の案内を出す
    public func accountDeletionGuide() async -> AccountDeletionGuide? {
        await AccountDeletionGuide.prepare(
            status: await recordSync.subscriptionStatus(), now: clock.now(),
            timeZone: clock.timeZone(), purchases: subscriptionPurchases)
    }

    public func rereadAccountDeletionGuide(_ guide: AccountDeletionGuide) async
        -> AccountDeletionGuide
    {
        await guide.rereadingRenewal(purchases: subscriptionPurchases)
    }

    public func signIn(with result: AppleSignInResult) async {
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

    public enum Screen: Equatable, Sendable {
        case opening
        case signIn(SignInDestination.Prompt, SignInStatus)
        case loadingTimeline
        case timeline

        public init(_ destination: SignInDestination) {
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
    private let termsAgreement: TermsAgreementPrompt
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
            // 途中の答え（手で入れた身体データを含む）を、次にサインインしたアカウントに持ち越さない
            goalSetup.discard()
            // サインアウトとアカウントの削除で、予約した通知と通知センターに残った通知を外し、前の時刻で待たない
            recordSync.stopWaitingForNoticeTime()
            Task { [recordSync] in await recordSync.stopFollowingReplies() }
            Task { [missedWeightRecordWatch] in await missedWeightRecordWatch.removeAll() }
            // 同意はサインインで送るので、前のアカウントのシートを残さない
            termsAgreementSheet = nil
        case .loadingTimeline, .timeline:
            break
        }
        screen = Screen(destination)
    }

    private func openFromReminderTappedWhileOpening(_ noticeId: UUID?) async {
        guard let noticeId else { return }
        await openFromReminder(noticeId: noticeId)
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

    /// シートを出しているあいだは問い直さない。問うあいだにサインインの画面に替わったら出さない
    private func askTermsAgreementIfShowingTimeline() async {
        guard termsAgreementSheet == nil, isShowingTimeline else { return }
        let sheet = await termsAgreement.sheetOnOpen()
        guard termsAgreementSheet == nil, isShowingTimeline else { return }
        termsAgreementSheet = sheet
    }

    /// サインインしていなければ、知らせる先のアカウントが無いので、取引を終えずに残し、サインインしたあとに開いたときに知らせる
    private func reportUnfinishedTransactionsIfShowingTimeline() async {
        guard isShowingTimeline else { return }
        await subscriptionPurchases.reportUnfinishedTransactions()
    }

    private var isShowingTimeline: Bool {
        switch screen {
        case .loadingTimeline, .timeline: true
        case .opening, .signIn: false
        }
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
