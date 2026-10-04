public import Foundation

/// 記録忘れの見張り。出来事のたびに、キャッシュから材料を1回だけ読んで記録忘れの計画（`MissedWeightRecordPlan`）を作り、
/// 計画どおりに体重の知らせの書き込みを送り待ちに積み、記録忘れの通知を置き直し、次に知らせを出すかを決める時刻を覚える。
/// 出来事と外すことは、呼んだ順に1つずつ扱う。並べて扱うと、同じ知らせの書き込みを二重に積み、前の計画の予約があとから残りうるため
public actor MissedWeightRecordWatch {
    public init(
        cache: any SyncBox & RecordCacheReading,
        center: any MissedWeightRecordReminderCenter,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        errorReporting: any ErrorReportingSession
    ) {
        self.cache = cache
        self.center = center
        self.timeZone = timeZone
        self.now = now
        self.errorReporting = errorReporting
    }

    public enum Event: Sendable {
        /// 記録忘れの通知を押して開いた。ヘルスケアを読んでから決める
        case reminderTapped
        /// 開いているあいだに、次に知らせを出すかを決める時刻が来た
        case noticeTimeReached
        /// 知らせの中で記録したときも、送るのを待たずに答えた形にする
        case weightRecorded
        /// 送り待ちを送る前。ヘルスケアから取り込んだ体重記録で決め、この同期で送る
        case syncStarting
        /// 取りに行き終えた。届いた体重記録といつもの時刻で決める
        case synced
        /// 体重のシートを開く。ヘルスケアから読み込んだ今日の体重で答える
        case weightEntryOpening
        /// 端末の日付かタイムゾーンが変わった
        case clockChanged
        /// ヘルスケアから体重記録を取り込んだ。このあとの同期の前に決める
        case healthImported
    }

    /// 初回の取得を終えるまでは、記録がそろっていないので知らせを決めない。
    /// 通知は、この機能で予約したものをすべて外してから置き直し、通知センターに残った通知のうち体重記録のある日の分も外す。
    /// 許可していなければ予約しない。キャッシュを読めなければ、報告して前の予約を残す。
    /// 知らせの書き込みを送り待ちに積んだかを返す
    @discardableResult
    public func refresh(after event: Event) async -> Bool {
        await inOrder { await $0.decideAndReschedule(event.noticeDecision) }
    }

    /// 開いているあいだに、次に知らせを出すかを決める時刻。最後に決めたときのもので、
    /// キャッシュを読めなかったときと、外したあと（サインアウト）は無い
    public func nextNoticeTime() -> Date? {
        lastNoticeTime
    }

    /// サインアウトとアカウントの削除のとき。予約した通知と、通知センターに残った通知を外し、次の時刻を忘れる
    public func removeAll() async {
        await inOrder { await $0.removeReminders() }
    }

    /// アカウントの画面の通知の行に出す、今の許可
    public func permission() async -> NotificationPermission {
        await center.permission()
    }

    /// この端末でまだ許可を求めていなければ、求めて許可したかを返す。許可したら置き直す。
    /// 求められなかったら、報告して許可しなかったものとして扱う
    @discardableResult
    public func requestPermissionIfNotYetRequested() async -> PermissionRequestOutcome {
        guard await center.permission() == .notYetRequested else { return .alreadyRequested }
        let granted: Bool
        do {
            granted = try await center.requestPermission()
        } catch {
            await report(error, as: .notificationPermissionRequest)
            granted = false
        }
        guard granted else { return .notGranted }
        // 許可を求めるのは体重を記録した直後で、知らせは記録したときにもう決めている
        _ = await inOrder { await $0.decideAndReschedule(.rescheduleOnly) }
        return .granted
    }

    public enum PermissionRequestOutcome: Sendable, Equatable {
        case granted
        case notGranted
        /// この端末で前に求めたので、求めなかった
        case alreadyRequested
    }

    private let cache: any SyncBox & RecordCacheReading
    private let center: any MissedWeightRecordReminderCenter
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let errorReporting: any ErrorReportingSession
    /// 呼んだ順に並べた仕事の、いちばん後ろ
    private var lastInOrder: Task<Void, Never>?
    /// 最後に決めた、次に知らせを出すかを決める時刻
    private var lastNoticeTime: Date?

    /// 出来事のあとに、知らせについて決めること
    fileprivate enum NoticeDecision {
        case issueOrRespond
        case respondOnly
        case rescheduleOnly
    }

    /// 知らせを決め、通知を置き直す材料
    private struct Materials {
        let hasCompletedInitialPull: Bool
        let weightRecords: [WeightRecord]
        let notices: [Notice]
        let usualWeighingTime: UsualWeighingTime?
    }

    private func inOrder<T: Sendable>(
        _ work: @escaping @Sendable (MissedWeightRecordWatch) async -> T
    ) async -> T {
        let previous = lastInOrder
        let task = Task {
            await previous?.value
            return await work(self)
        }
        lastInOrder = Task { _ = await task.value }
        return await task.value
    }

    private func decideAndReschedule(_ decision: NoticeDecision) async -> Bool {
        let materials: Materials
        do {
            materials = Materials(
                hasCompletedInitialPull: try await cache.syncState()?.hasCompletedInitialPull
                    ?? false,
                weightRecords: try await cache.weightRecords(),
                notices: try await cache.notices(),
                usualWeighingTime: try await cache.usualWeighingTime()
            )
        } catch {
            await report(error, as: .cacheRead)
            lastNoticeTime = nil
            return false
        }
        let now = now()
        let timeZone = timeZone()
        let plan = MissedWeightRecordPlan(
            weightRecords: materials.weightRecords, notices: materials.notices,
            usualWeighingTime: materials.usualWeighingTime, now: now, timeZone: timeZone)
        let enqueued: Bool
        switch decision {
        case _ where !materials.hasCompletedInitialPull, .rescheduleOnly:
            enqueued = false
        case .issueOrRespond:
            enqueued = await enqueueNoticeWrites(
                responding: plan.noticesToRespond, issuing: plan.noticeToIssue, now: now,
                timeZone: timeZone)
        case .respondOnly:
            enqueued = await enqueueNoticeWrites(
                responding: plan.noticesToRespond, issuing: nil, now: now, timeZone: timeZone)
        }
        await replaceReminders(with: plan)
        lastNoticeTime = plan.nextNoticeTime
        return enqueued
    }

    /// 答える書き込みを先に、出す書き込みをあとに積む。積めなかったら報告し、それより前に積めたかを返す
    private func enqueueNoticeWrites(
        responding noticesToRespond: [Notice], issuing noticeToIssue: Notice?, now: Date,
        timeZone: TimeZone
    ) async -> Bool {
        let response = Notice.Response(respondedAt: now, timeZone: timeZone)
        var enqueued = false
        do {
            for notice in noticesToRespond {
                try await cache.apply(
                    NoticeSyncing().responding(
                        to: notice, with: response,
                        enqueuing: Pending(
                            enqueuedAt: now,
                            write: .respond(noticeId: notice.id, response: response))))
                enqueued = true
            }
            if let noticeToIssue {
                try await cache.apply(
                    NoticeSyncing().issuing(
                        noticeToIssue,
                        enqueuing: Pending(enqueuedAt: now, write: .create(noticeToIssue))))
                enqueued = true
            }
        } catch {
            await report(error, as: .cacheSave)
        }
        return enqueued
    }

    private func replaceReminders(with plan: MissedWeightRecordPlan) async {
        await center.removeScheduled(ids: await center.scheduledIds())
        let deliveredToRemove = plan.deliveredIdsToRemove(from: await center.deliveredIds())
        if !deliveredToRemove.isEmpty {
            await center.removeDelivered(ids: deliveredToRemove)
        }
        guard await center.permission() == .permitted else { return }
        for reminder in plan.reminders {
            do {
                try await center.schedule(reminder)
            } catch {
                await report(error, as: .reminderSchedule)
                return
            }
        }
    }

    private func removeReminders() async {
        lastNoticeTime = nil
        await center.removeScheduled(ids: await center.scheduledIds())
        await center.removeDelivered(ids: await center.deliveredIds())
    }

    private func report(_ error: any Error, as area: HandledFailure) async {
        if let failure = HandledFailure.reported(error, as: area) {
            await errorReporting.report(failure)
        }
    }
}

extension MissedWeightRecordWatch.Event {
    /// 体重のシートを開くときは、知らせを出す時機でない。時計とヘルスケアの変化のあとは、次の同期の前に決める
    fileprivate var noticeDecision: MissedWeightRecordWatch.NoticeDecision {
        switch self {
        case .reminderTapped, .noticeTimeReached, .weightRecorded, .syncStarting, .synced:
            .issueOrRespond
        case .weightEntryOpening: .respondOnly
        case .clockChanged, .healthImported: .rescheduleOnly
        }
    }
}
