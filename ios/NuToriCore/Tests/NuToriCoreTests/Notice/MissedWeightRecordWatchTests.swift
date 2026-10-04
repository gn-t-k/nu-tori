import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

/// 東京の 2026年9月。いつもの時刻が無いので、通知の時刻は 8:00
@Suite("記録忘れの見張り")
struct MissedWeightRecordWatchTests {
    struct SampleError: Error {}

    /// 2026年9月のその日の、記録忘れの知らせと通知の ID
    static func id(_ day: Int) -> UUID {
        Notice.id(
            kind: .missedWeightRecord, targetDay: CalendarDay(year: 2026, month: 9, day: day))
    }

    static func watch(
        store: any SyncBox & RecordCacheReading,
        center: MissedWeightRecordReminderCenterMock = .ok(),
        now: String,
        errorReporting: ErrorReportingSessionMock = .ok()
    ) throws -> MissedWeightRecordWatch {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let now = try Date(now, strategy: .iso8601)
        return MissedWeightRecordWatch(
            cache: store,
            center: center,
            timeZone: { tokyo },
            now: { now },
            errorReporting: errorReporting
        )
    }

    @Suite("知らせを出してよい出来事のとき")
    struct Issuing {
        @Suite("初回の取得を終え、今日の体重記録が無く、今日の通知の時刻を過ぎたとき")
        struct DueToday {
            let store: SyncBoxMock<RecordCacheMock>
            let center: MissedWeightRecordReminderCenterMock
            let watch: MissedWeightRecordWatch

            init() throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                center = .ok()
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, center: center, now: "2026-09-22T09:00:00+09:00")
            }

            @Test("今日の知らせを、通知の時刻に出したものとして作り、送り待ちに積んでからキャッシュに置くこと")
            func issuesTodayNotice() async throws {
                let outcome = await watch.refresh(after: .reminderTapped)

                #expect(outcome.enqueuedWrites)
                #expect(store.entries.map(\.kind) == [.notice])
                #expect(
                    store.saves == [
                        .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                    ])
                #expect(
                    store.cache.notices[MissedWeightRecordWatchTests.id(22)]?.issuedAt
                        == (try Date("2026-09-22T08:00:00+09:00", strategy: .iso8601)))
            }

            @Test("時刻を過ぎた今日の通知は予約せず、明日から予約すること")
            func schedulesFromTomorrow() async {
                await watch.refresh(after: .reminderTapped)

                #expect(!center.scheduled.contains(MissedWeightRecordWatchTests.id(22)))
                #expect(center.scheduled.contains(MissedWeightRecordWatchTests.id(23)))
            }

            @Test("次に知らせを出すかを決める時刻として、明日の通知の時刻を返すこと")
            func returnsTomorrowNoticeTime() async throws {
                let outcome = await watch.refresh(after: .reminderTapped)

                #expect(
                    outcome.nextNoticeTime
                        == (try Date("2026-09-23T08:00:00+09:00", strategy: .iso8601)))
            }
        }

        @Suite("今日の知らせをもう出したとき")
        struct AlreadyIssued {
            let store: SyncBoxMock<RecordCacheMock>
            let watch: MissedWeightRecordWatch

            init() async throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, now: "2026-09-22T09:00:00+09:00")
                await watch.refresh(after: .reminderTapped)
            }

            @Test("もう一度決めても、知らせを足さないこと")
            func issuesOnce() async {
                let outcome = await watch.refresh(after: .synced)

                #expect(!outcome.enqueuedWrites)
                #expect(store.entries.map(\.kind) == [.notice])
            }
        }

        @Suite("知らせを出す時機で、読むあいだにほかの出来事が割り込めるとき")
        struct Overlapping {
            let store: SyncBoxMock<RecordCacheMock>
            let watch: MissedWeightRecordWatch

            init() throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                watch = try MissedWeightRecordWatchTests.watch(
                    store: YieldingSyncBoxMock(store), now: "2026-09-22T09:00:00+09:00")
            }

            @Test("出来事が重なっても、知らせの書き込みを1つだけ積むこと")
            func issuesOnce() async {
                async let weightRecorded = watch.refresh(after: .weightRecorded)
                async let syncStarting = watch.refresh(after: .syncStarting)
                async let synced = watch.refresh(after: .synced)
                _ = await (weightRecorded, syncStarting, synced)

                #expect(store.entries.map(\.kind) == [.notice])
            }
        }

        @Suite("初回の取得を終えていないとき")
        struct BeforeInitialPull {
            let store: SyncBoxMock<RecordCacheMock>
            let center: MissedWeightRecordReminderCenterMock
            let watch: MissedWeightRecordWatch

            init() throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: false))
                center = .ok()
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, center: center, now: "2026-09-22T09:00:00+09:00")
            }

            @Test("記録がそろっていないので、知らせを出さないこと")
            func issuesNothing() async {
                let outcome = await watch.refresh(after: .reminderTapped)

                #expect(!outcome.enqueuedWrites)
                #expect(store.entries.isEmpty)
                #expect(store.cache.notices.isEmpty)
            }

            @Test("通知は予約すること")
            func schedulesReminders() async {
                await watch.refresh(after: .reminderTapped)

                #expect(center.scheduled.contains(MissedWeightRecordWatchTests.id(23)))
            }
        }

        @Suite("答えていない今日の知らせがあり、今日の体重記録が届いたとき")
        struct RecordedAfterNotice {
            let store: SyncBoxMock<RecordCacheMock>
            let watch: MissedWeightRecordWatch

            init() async throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, now: "2026-09-22T09:00:00+09:00")
                await watch.refresh(after: .reminderTapped)
                store.cache.upsert(
                    try WeightRecord.imported(
                        72.4, at: "2026-09-22T08:50:00+09:00", in: "Asia/Tokyo"))
            }

            @Test("知らせを今の時刻とタイムゾーンで答えた形にし、答える書き込みを送り待ちに積むこと")
            func respondsToNotice() async throws {
                let outcome = await watch.refresh(after: .synced)

                #expect(outcome.enqueuedWrites)
                #expect(store.entries.map(\.kind) == [.notice, .notice])
                #expect(
                    store.cache.notices[MissedWeightRecordWatchTests.id(22)]?.response
                        == Notice.Response(
                            respondedAt: try Date("2026-09-22T09:00:00+09:00", strategy: .iso8601),
                            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))))
            }
        }

        @Suite("今日の体重記録で、今日の知らせにもう答えたとき")
        struct AlreadyResponded {
            let store: SyncBoxMock<RecordCacheMock>
            let watch: MissedWeightRecordWatch

            init() async throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, now: "2026-09-22T09:00:00+09:00")
                await watch.refresh(after: .reminderTapped)
                store.cache.upsert(
                    try WeightRecord.imported(
                        72.4, at: "2026-09-22T08:50:00+09:00", in: "Asia/Tokyo"))
                await watch.refresh(after: .synced)
            }

            @Test("もう一度決めても、答える書き込みを足さないこと")
            func respondsOnce() async {
                let outcome = await watch.refresh(after: .synced)

                #expect(!outcome.enqueuedWrites)
                #expect(store.entries.map(\.kind) == [.notice, .notice])
            }
        }
    }

    @Suite("体重のシートを開くとき")
    struct WeightEntryOpening {
        @Suite("今日の通知の時刻を過ぎ、今日の体重記録も知らせも無いとき")
        struct DueToday {
            let store: SyncBoxMock<RecordCacheMock>
            let watch: MissedWeightRecordWatch

            init() throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, now: "2026-09-22T09:00:00+09:00")
            }

            @Test("知らせを作らないこと")
            func issuesNothing() async {
                let outcome = await watch.refresh(after: .weightEntryOpening)

                #expect(!outcome.enqueuedWrites)
                #expect(store.entries.isEmpty)
                #expect(store.cache.notices.isEmpty)
            }
        }

        @Suite("答えていない今日の知らせがあり、ヘルスケアから今日の体重記録を読み込んだとき")
        struct RecordedAfterNotice {
            let store: SyncBoxMock<RecordCacheMock>
            let watch: MissedWeightRecordWatch

            init() async throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, now: "2026-09-22T09:00:00+09:00")
                await watch.refresh(after: .reminderTapped)
                store.cache.upsert(
                    try WeightRecord.imported(
                        72.4, at: "2026-09-22T08:50:00+09:00", in: "Asia/Tokyo"))
            }

            @Test("知らせを答えた形にし、答える書き込みを送り待ちに積むこと")
            func respondsToNotice() async {
                let outcome = await watch.refresh(after: .weightEntryOpening)

                #expect(outcome.enqueuedWrites)
                #expect(store.entries.map(\.kind) == [.notice, .notice])
                #expect(store.cache.notices[MissedWeightRecordWatchTests.id(22)]?.response != nil)
            }
        }
    }

    @Suite("時計が変わったときと、ヘルスケアから取り込んだとき")
    struct RescheduleOnly {
        @Suite("答えていない今日の知らせがあり、今日の体重記録が入ったとき")
        struct RecordedAfterNotice {
            let store: SyncBoxMock<RecordCacheMock>
            let watch: MissedWeightRecordWatch

            init() async throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                watch = try MissedWeightRecordWatchTests.watch(
                    store: store, now: "2026-09-22T09:00:00+09:00")
                await watch.refresh(after: .reminderTapped)
                store.cache.upsert(
                    try WeightRecord.imported(
                        72.4, at: "2026-09-22T08:50:00+09:00", in: "Asia/Tokyo"))
            }

            @Test("時計が変わっても、答えず置き直すだけにすること")
            func clockChangedDoesNotRespond() async {
                let outcome = await watch.refresh(after: .clockChanged)

                #expect(!outcome.enqueuedWrites)
                #expect(store.entries.map(\.kind) == [.notice])
            }

            @Test("ヘルスケアから取り込んでも、答えず置き直すだけにすること")
            func healthImportedDoesNotRespond() async {
                let outcome = await watch.refresh(after: .healthImported)

                #expect(!outcome.enqueuedWrites)
                #expect(store.entries.map(\.kind) == [.notice])
            }
        }
    }

    /// 今は 2026-09-22 7:00 で、今日の通知の時刻の前
    @Suite("通知を置き直すとき")
    struct Rescheduling {
        @Suite("許可していて、前に置いた予約が残り、明日の体重記録があるとき")
        struct Permitted {
            let center: MissedWeightRecordReminderCenterMock
            let watch: MissedWeightRecordWatch

            init() throws {
                center = .ok(scheduled: [MissedWeightRecordWatchTests.id(21)])
                watch = try MissedWeightRecordWatchTests.watch(
                    store: SyncBoxMock<RecordCacheMock>.ok(records: [
                        .manual(72.4, at: "2026-09-23T07:10:00+09:00", in: "Asia/Tokyo")
                    ]),
                    center: center, now: "2026-09-22T07:00:00+09:00")
            }

            @Test("前に置いた予約を外すこと")
            func removesPreviousReminders() async {
                await watch.refresh(after: .clockChanged)

                #expect(!center.scheduled.contains(MissedWeightRecordWatchTests.id(21)))
            }

            @Test("今日から予約し、体重記録のある明日は予約しないこと")
            func schedulesThePlan() async {
                await watch.refresh(after: .clockChanged)

                #expect(center.scheduled.contains(MissedWeightRecordWatchTests.id(22)))
                #expect(!center.scheduled.contains(MissedWeightRecordWatchTests.id(23)))
                #expect(center.scheduled.contains(MissedWeightRecordWatchTests.id(24)))
            }

            @Test("次に知らせを出すかを決める時刻として、今日の通知の時刻を返すこと")
            func returnsTodayNoticeTime() async throws {
                let outcome = await watch.refresh(after: .clockChanged)

                #expect(
                    outcome.nextNoticeTime
                        == (try Date("2026-09-22T08:00:00+09:00", strategy: .iso8601)))
            }
        }

        @Suite("通知センターに、体重記録のある日の通知と無い日の通知が残っているとき")
        struct DeliveredReminders {
            let center: MissedWeightRecordReminderCenterMock
            let watch: MissedWeightRecordWatch

            init() throws {
                center = .ok(delivered: [
                    MissedWeightRecordWatchTests.id(20), MissedWeightRecordWatchTests.id(21),
                ])
                watch = try MissedWeightRecordWatchTests.watch(
                    store: SyncBoxMock<RecordCacheMock>.ok(records: [
                        .manual(72.4, at: "2026-09-21T21:00:00+09:00", in: "Asia/Tokyo")
                    ]),
                    center: center, now: "2026-09-22T07:00:00+09:00")
            }

            @Test("体重記録のある日の通知だけを外すこと")
            func removesRecordedDays() async {
                await watch.refresh(after: .healthImported)

                #expect(center.delivered == [MissedWeightRecordWatchTests.id(20)])
            }
        }

        @Suite("通知を許可していないとき")
        struct NotPermitted {
            let center: MissedWeightRecordReminderCenterMock
            let watch: MissedWeightRecordWatch

            init() throws {
                center = .ok(
                    permission: .notPermitted, scheduled: [MissedWeightRecordWatchTests.id(21)])
                watch = try MissedWeightRecordWatchTests.watch(
                    store: SyncBoxMock<RecordCacheMock>.ok(), center: center,
                    now: "2026-09-22T07:00:00+09:00")
            }

            @Test("前に置いた予約を外し、何も予約しないこと")
            func schedulesNothing() async {
                await watch.refresh(after: .clockChanged)

                #expect(center.scheduled.isEmpty)
            }

            @Test("次に知らせを出すかを決める時刻は返すこと")
            func returnsNoticeTime() async {
                let outcome = await watch.refresh(after: .clockChanged)

                #expect(outcome.nextNoticeTime != nil)
            }
        }

        @Suite("予約に失敗したとき")
        struct ScheduleFails {
            let errorReporting: ErrorReportingSessionMock
            let watch: MissedWeightRecordWatch

            init() throws {
                errorReporting = .ok()
                watch = try MissedWeightRecordWatchTests.watch(
                    store: SyncBoxMock<RecordCacheMock>.ok(), center: .error(SampleError()),
                    now: "2026-09-22T07:00:00+09:00",
                    errorReporting: errorReporting)
            }

            @Test("通知の予約の失敗として1回送ること")
            func reportsOnce() async {
                await watch.refresh(after: .clockChanged)

                #expect(errorReporting.reported == [.reminderSchedule])
            }
        }
    }

    @Suite("キャッシュを読めないとき")
    struct CacheUnreadable {
        let center: MissedWeightRecordReminderCenterMock
        let errorReporting: ErrorReportingSessionMock
        let watch: MissedWeightRecordWatch

        init() throws {
            center = .ok(scheduled: [MissedWeightRecordWatchTests.id(21)])
            errorReporting = .ok()
            watch = try MissedWeightRecordWatchTests.watch(
                store: SyncBoxMock<RecordCacheMock>.error(SampleError()), center: center,
                now: "2026-09-22T09:00:00+09:00",
                errorReporting: errorReporting)
        }

        @Test("積まず、次の時刻も返さないこと")
        func decidesNothing() async {
            let outcome = await watch.refresh(after: .reminderTapped)

            #expect(!outcome.enqueuedWrites)
            #expect(outcome.nextNoticeTime == nil)
        }

        @Test("キャッシュを読めなかった失敗として1回送ること")
        func reportsReadFailure() async {
            await watch.refresh(after: .reminderTapped)

            #expect(errorReporting.reported == [.cacheRead])
        }

        @Test("前に置いた予約を残すこと")
        func keepsPreviousReminders() async {
            await watch.refresh(after: .reminderTapped)

            #expect(center.scheduled == [MissedWeightRecordWatchTests.id(21)])
        }
    }

    @Suite("サインアウトとアカウントの削除で外すとき")
    struct RemoveAll {
        let center: MissedWeightRecordReminderCenterMock
        let watch: MissedWeightRecordWatch

        init() throws {
            center = .ok(
                scheduled: [MissedWeightRecordWatchTests.id(23)],
                delivered: [MissedWeightRecordWatchTests.id(21)])
            watch = try MissedWeightRecordWatchTests.watch(
                store: SyncBoxMock<RecordCacheMock>.ok(), center: center,
                now: "2026-09-22T07:00:00+09:00")
        }

        @Test("予約した通知と、通知センターに残った通知を外すこと")
        func removesEverything() async {
            await watch.removeAll()

            #expect(center.scheduled.isEmpty)
            #expect(center.delivered.isEmpty)
        }
    }

    @Suite("初めて体重を記録したあとに許可を求めるとき")
    struct RequestPermission {
        @Suite("まだ求めておらず、許可したとき")
        struct NotYetRequested {
            let center: MissedWeightRecordReminderCenterMock
            let watch: MissedWeightRecordWatch

            init() throws {
                center = .ok(permission: .notYetRequested, grantsPermission: true)
                watch = try MissedWeightRecordWatchTests.watch(
                    store: SyncBoxMock<RecordCacheMock>.ok(), center: center,
                    now: "2026-09-22T07:00:00+09:00")
            }

            @Test("許可したことを返すこと")
            func returnsGranted() async {
                let outcome = await watch.requestPermissionIfNotYetRequested()

                #expect(outcome == .granted)
            }

            @Test("予約し直すこと")
            func reschedules() async {
                await watch.requestPermissionIfNotYetRequested()

                #expect(center.scheduled.contains(MissedWeightRecordWatchTests.id(22)))
            }
        }

        @Suite("前に許可しなかったとき")
        struct AlreadyDenied {
            let center: MissedWeightRecordReminderCenterMock
            let watch: MissedWeightRecordWatch

            init() throws {
                center = .ok(permission: .notPermitted)
                watch = try MissedWeightRecordWatchTests.watch(
                    store: SyncBoxMock<RecordCacheMock>.ok(), center: center,
                    now: "2026-09-22T07:00:00+09:00")
            }

            @Test("求めず、求めたことがあると返すこと")
            func doesNotAsk() async {
                let outcome = await watch.requestPermissionIfNotYetRequested()

                #expect(outcome == .alreadyRequested)
                #expect(center.permissionRequestCount == 0)
            }
        }

        @Suite("まだ求めておらず、許可を求められないとき")
        struct RequestFails {
            let errorReporting: ErrorReportingSessionMock
            let watch: MissedWeightRecordWatch

            init() throws {
                errorReporting = .ok()
                watch = try MissedWeightRecordWatchTests.watch(
                    store: SyncBoxMock<RecordCacheMock>.ok(),
                    center: .permissionRequestError(SampleError()),
                    now: "2026-09-22T07:00:00+09:00", errorReporting: errorReporting)
            }

            @Test("許可しなかったことを返すこと")
            func returnsNotGranted() async {
                let outcome = await watch.requestPermissionIfNotYetRequested()

                #expect(outcome == .notGranted)
            }

            @Test("通知の許可を求められなかった失敗として1回送ること")
            func reportsOnce() async {
                await watch.requestPermissionIfNotYetRequested()

                #expect(errorReporting.reported == [.notificationPermissionRequest])
            }
        }
    }
}
