public import Foundation

/// 記録忘れの通知を、予約の計画（`MissedWeightRecordReminder.plan`）どおりに置き直す。
/// 置き直しと外すことは、呼んだ順に1つずつ行う。並べて行うと、前の計画の予約があとから残りうるため
public actor MissedWeightRecordReminderScheduler {
    public init(
        center: any MissedWeightRecordReminderCenter,
        cache: any RecordCacheReading,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        errorReporting: any ErrorReportingSession
    ) {
        self.center = center
        self.cache = cache
        self.timeZone = timeZone
        self.now = now
        self.errorReporting = errorReporting
    }

    /// この機能で予約したものをすべて外してから、計画どおりに置き直す。
    /// 通知センターに残った通知のうち、体重記録のある日の分も外す。許可していなければ予約しない
    public func reschedule() async {
        await inOrder { await $0.replaceReminders() }
    }

    /// サインアウトとアカウントの削除のとき。予約した通知と、通知センターに残った通知を外す
    public func removeAll() async {
        await inOrder { await $0.removeReminders() }
    }

    /// この端末でまだ許可を求めていなければ、求めて許可したかを返す。許可したら予約し直す。
    /// 求めたことがあれば、求めずに nil
    @discardableResult
    public func requestPermissionIfNotYetRequested() async -> Bool? {
        guard await center.permission() == .notYetRequested else { return nil }
        let granted = (try? await center.requestPermission()) ?? false
        if granted {
            await reschedule()
        }
        return granted
    }

    private let center: any MissedWeightRecordReminderCenter
    private let cache: any RecordCacheReading
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let errorReporting: any ErrorReportingSession
    private var last: Task<Void, Never>?

    private func inOrder(
        _ work: @escaping @Sendable (MissedWeightRecordReminderScheduler) async -> Void
    ) async {
        let previous = last
        let task = Task {
            await previous?.value
            await work(self)
        }
        last = task
        await task.value
    }

    private func replaceReminders() async {
        let weightRecords: [WeightRecord]
        let usualWeighingTime: UsualWeighingTime?
        do {
            weightRecords = try await cache.weightRecords()
            usualWeighingTime = try await cache.usualWeighingTime()
        } catch {
            return
        }
        await center.removeScheduled(ids: await center.scheduledIds())
        let recordedDayIds = Set(
            weightRecords.map { Notice.id(kind: .missedWeightRecord, targetDay: $0.day) })
        let deliveredOnRecordedDays = await center.deliveredIds().filter(recordedDayIds.contains)
        if !deliveredOnRecordedDays.isEmpty {
            await center.removeDelivered(ids: deliveredOnRecordedDays)
        }
        guard await center.permission() == .permitted else { return }
        let reminders = MissedWeightRecordReminder.plan(
            usualWeighingTime: usualWeighingTime, now: now(), timeZone: timeZone(),
            weightRecords: weightRecords)
        for reminder in reminders {
            do {
                try await center.schedule(reminder)
            } catch {
                if let failure = HandledFailure.reported(error, as: .reminderSchedule) {
                    await errorReporting.report(failure)
                }
                return
            }
        }
    }

    private func removeReminders() async {
        await center.removeScheduled(ids: await center.scheduledIds())
        await center.removeDelivered(ids: await center.deliveredIds())
    }
}
