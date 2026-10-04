public import Foundation

/// 記録忘れの見張り。出来事のたびに、キャッシュから材料を1回だけ読み、体重の知らせを出すか・答えるかを決めて送り待ちに積み、
/// 記録忘れの通知を予約の計画（`MissedWeightRecordReminder.plan`）どおりに置き直し、次に知らせを出すかを決める時刻を返す。
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
        /// 開いた・前面に戻った、記録忘れの通知を押した
        case opened
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
        case healthImported
    }

    public struct Outcome: Sendable, Equatable {
        /// 知らせの書き込みを送り待ちに積んだか
        public let enqueuedWrites: Bool
        /// 開いているあいだに、次に知らせを出すかを決める時刻。キャッシュを読めなかったときは無い
        public let nextNoticeTime: Date?
    }

    /// 初回の取得を終えるまでは、記録がそろっていないので知らせを決めない。
    /// 通知は、この機能で予約したものをすべて外してから置き直し、通知センターに残った通知のうち体重記録のある日の分も外す。
    /// 許可していなければ予約しない。キャッシュを読めなければ、報告して前の予約を残す
    @discardableResult
    public func refresh(after event: Event) async -> Outcome {
        await inOrder { await $0.decideAndReschedule(issuing: event.mayIssueNotice) }
    }

    /// サインアウトとアカウントの削除のとき。予約した通知と、通知センターに残った通知を外す
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
        // 積んだ答えは次の同期で送る。許可を求めるのは体重を記録した直後で、記録したときにもう答えている
        _ = await inOrder { await $0.decideAndReschedule(issuing: false) }
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
    private var last: Task<Void, Never>?

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
        let previous = last
        let task = Task {
            await previous?.value
            return await work(self)
        }
        last = Task { _ = await task.value }
        return await task.value
    }

    private func decideAndReschedule(issuing: Bool) async -> Outcome {
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
            return Outcome(enqueuedWrites: false, nextNoticeTime: nil)
        }
        let now = now()
        let timeZone = timeZone()
        let enqueued =
            materials.hasCompletedInitialPull
            ? await enqueueNoticeWrites(
                from: materials, issuing: issuing, now: now, timeZone: timeZone)
            : false
        let plan = MissedWeightRecordReminder.plan(
            usualWeighingTime: materials.usualWeighingTime, now: now, timeZone: timeZone,
            weightRecords: materials.weightRecords)
        await replaceReminders(with: plan, weightRecords: materials.weightRecords)
        return Outcome(
            enqueuedWrites: enqueued,
            nextNoticeTime: MissedWeightRecordNoticeDecision.nextNoticeTime(
                usualWeighingTime: materials.usualWeighingTime, now: now, timeZone: timeZone,
                weightRecords: materials.weightRecords))
    }

    /// 答える書き込みを先に、出す書き込みをあとに積む。積めなかったら報告し、それより前に積めたかを返す
    private func enqueueNoticeWrites(
        from materials: Materials, issuing: Bool, now: Date, timeZone: TimeZone
    ) async -> Bool {
        let idsToRespond = Set(
            MissedWeightRecordNoticeDecision.noticeIdsToRespond(
                notices: materials.notices, weightRecords: materials.weightRecords))
        let response = Notice.Response(respondedAt: now, timeZone: timeZone)
        let noticeToIssue =
            issuing
            ? MissedWeightRecordNoticeDecision.noticeToIssue(
                usualWeighingTime: materials.usualWeighingTime, now: now, timeZone: timeZone,
                weightRecords: materials.weightRecords, notices: materials.notices)
            : nil
        var enqueued = false
        do {
            for notice in materials.notices where idsToRespond.contains(notice.id) {
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

    private func replaceReminders(
        with plan: [MissedWeightRecordReminder], weightRecords: [WeightRecord]
    ) async {
        await center.removeScheduled(ids: await center.scheduledIds())
        let recordedDayIds = Set(
            weightRecords.map { Notice.id(kind: .missedWeightRecord, targetDay: $0.day) })
        let deliveredOnRecordedDays = await center.deliveredIds().filter(recordedDayIds.contains)
        if !deliveredOnRecordedDays.isEmpty {
            await center.removeDelivered(ids: deliveredOnRecordedDays)
        }
        guard await center.permission() == .permitted else { return }
        for reminder in plan {
            do {
                try await center.schedule(reminder)
            } catch {
                await report(error, as: .reminderSchedule)
                return
            }
        }
    }

    private func removeReminders() async {
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
    /// 知らせを出す時機か。体重のシートを開くときは出す時機でなく、時計とヘルスケアの変化は開いたことを表さない
    fileprivate var mayIssueNotice: Bool {
        switch self {
        case .opened, .noticeTimeReached, .weightRecorded, .syncStarting, .synced: true
        case .weightEntryOpening, .clockChanged, .healthImported: false
        }
    }
}
