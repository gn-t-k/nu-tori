import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

/// 今は 2026-09-22 7:00（東京）。いつもの時刻が無いので、通知の時刻は 8:00
@Suite("記録忘れの通知の予約")
struct MissedWeightRecordReminderSchedulerTests {
    struct SampleError: Error {}

    /// 2026年9月のその日の、記録忘れの通知の ID
    static func id(_ day: Int) -> UUID {
        Notice.id(
            kind: .missedWeightRecord, targetDay: CalendarDay(year: 2026, month: 9, day: day))
    }

    static func scheduler(
        center: MissedWeightRecordReminderCenterMock,
        store: SyncBoxMock<RecordCacheMock>,
        errorReporting: ErrorReportingSessionMock = .ok()
    ) throws -> MissedWeightRecordReminderScheduler {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let now = try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601)
        return MissedWeightRecordReminderScheduler(
            center: center,
            cache: store,
            timeZone: { tokyo },
            now: { now },
            errorReporting: errorReporting
        )
    }

    @Suite("予約し直すとき")
    struct Reschedule {
        @Suite("許可していて、前に置いた予約が残り、明日の体重記録があるとき")
        struct Permitted {
            let center: MissedWeightRecordReminderCenterMock
            let scheduler: MissedWeightRecordReminderScheduler

            init() throws {
                center = .ok(scheduled: [MissedWeightRecordReminderSchedulerTests.id(21)])
                scheduler = try MissedWeightRecordReminderSchedulerTests.scheduler(
                    center: center,
                    store: .ok(records: [
                        .manual(72.4, at: "2026-09-23T07:10:00+09:00", in: "Asia/Tokyo")
                    ]))
            }

            @Test("前に置いた予約を外すこと")
            func removesPreviousReminders() async {
                await scheduler.reschedule()

                #expect(!center.scheduled.contains(MissedWeightRecordReminderSchedulerTests.id(21)))
            }

            @Test("今日から予約し、体重記録のある明日は予約しないこと")
            func schedulesThePlan() async {
                await scheduler.reschedule()

                #expect(center.scheduled.contains(MissedWeightRecordReminderSchedulerTests.id(22)))
                #expect(!center.scheduled.contains(MissedWeightRecordReminderSchedulerTests.id(23)))
                #expect(center.scheduled.contains(MissedWeightRecordReminderSchedulerTests.id(24)))
            }
        }

        @Suite("通知センターに、体重記録のある日の通知と無い日の通知が残っているとき")
        struct DeliveredReminders {
            let center: MissedWeightRecordReminderCenterMock
            let scheduler: MissedWeightRecordReminderScheduler

            init() throws {
                center = .ok(delivered: [
                    MissedWeightRecordReminderSchedulerTests.id(20),
                    MissedWeightRecordReminderSchedulerTests.id(21),
                ])
                scheduler = try MissedWeightRecordReminderSchedulerTests.scheduler(
                    center: center,
                    store: .ok(records: [
                        .manual(72.4, at: "2026-09-21T21:00:00+09:00", in: "Asia/Tokyo")
                    ]))
            }

            @Test("体重記録のある日の通知だけを外すこと")
            func removesRecordedDays() async {
                await scheduler.reschedule()

                #expect(center.delivered == [MissedWeightRecordReminderSchedulerTests.id(20)])
            }
        }

        @Suite("通知を許可していないとき")
        struct NotPermitted {
            let center: MissedWeightRecordReminderCenterMock
            let scheduler: MissedWeightRecordReminderScheduler

            init() throws {
                center = .ok(
                    permission: .notPermitted,
                    scheduled: [MissedWeightRecordReminderSchedulerTests.id(21)])
                scheduler = try MissedWeightRecordReminderSchedulerTests.scheduler(
                    center: center, store: .ok())
            }

            @Test("前に置いた予約を外し、何も予約しないこと")
            func schedulesNothing() async {
                await scheduler.reschedule()

                #expect(center.scheduled.isEmpty)
            }
        }

        @Suite("予約に失敗したとき")
        struct ScheduleFails {
            let errorReporting: ErrorReportingSessionMock
            let scheduler: MissedWeightRecordReminderScheduler

            init() throws {
                errorReporting = .ok()
                scheduler = try MissedWeightRecordReminderSchedulerTests.scheduler(
                    center: .error(SampleError()), store: .ok(), errorReporting: errorReporting)
            }

            @Test("通知の予約の失敗として1回送ること")
            func reportsOnce() async {
                await scheduler.reschedule()

                #expect(errorReporting.reported == [.reminderSchedule])
            }
        }
    }

    @Suite("サインアウトとアカウントの削除で外すとき")
    struct RemoveAll {
        let center: MissedWeightRecordReminderCenterMock
        let scheduler: MissedWeightRecordReminderScheduler

        init() throws {
            center = .ok(
                scheduled: [MissedWeightRecordReminderSchedulerTests.id(23)],
                delivered: [MissedWeightRecordReminderSchedulerTests.id(21)])
            scheduler = try MissedWeightRecordReminderSchedulerTests.scheduler(
                center: center, store: .ok())
        }

        @Test("予約した通知と、通知センターに残った通知を外すこと")
        func removesEverything() async {
            await scheduler.removeAll()

            #expect(center.scheduled.isEmpty)
            #expect(center.delivered.isEmpty)
        }
    }

    @Suite("初めて体重を記録したあとに許可を求めるとき")
    struct RequestPermission {
        @Suite("まだ求めておらず、許可したとき")
        struct NotYetRequested {
            let center: MissedWeightRecordReminderCenterMock
            let scheduler: MissedWeightRecordReminderScheduler

            init() throws {
                center = .ok(permission: .notYetRequested, grantsPermission: true)
                scheduler = try MissedWeightRecordReminderSchedulerTests.scheduler(
                    center: center, store: .ok())
            }

            @Test("許可したことを返すこと")
            func returnsGranted() async {
                let granted = await scheduler.requestPermissionIfNotYetRequested()

                #expect(granted == true)
            }

            @Test("予約し直すこと")
            func reschedules() async {
                await scheduler.requestPermissionIfNotYetRequested()

                #expect(center.scheduled.contains(MissedWeightRecordReminderSchedulerTests.id(22)))
            }
        }

        @Suite("前に許可しなかったとき")
        struct AlreadyDenied {
            let center: MissedWeightRecordReminderCenterMock
            let scheduler: MissedWeightRecordReminderScheduler

            init() throws {
                center = .ok(permission: .notPermitted)
                scheduler = try MissedWeightRecordReminderSchedulerTests.scheduler(
                    center: center, store: .ok())
            }

            @Test("求めず、nil を返すこと")
            func doesNotAsk() async {
                let granted = await scheduler.requestPermissionIfNotYetRequested()

                #expect(granted == nil)
                #expect(center.permissionRequestCount == 0)
            }
        }
    }
}
