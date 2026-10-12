import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

/// 初回の取得を終えてサインインしている端末。偽の同期サーバーにつなぎ、時計はテストが進める
struct RecordSyncDevice {
    static let startedOn = "2026-09-22"

    let clock: SteppingClock
    let server: FakeSyncServerProbe
    let store: SyncBoxMock<RecordCacheMock>
    let reflection: RecordSyncReflectionMock
    let recordSync: RecordSync

    /// `server` は、`clock` を渡して作った偽の同期サーバー
    init(clock: SteppingClock, server: FakeSyncServerProbe) throws {
        let kinds = RecordKindRegistry<RecordCacheMock>.ok()
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        // 記録忘れの通知の時刻（8:00）より前。知らせの書き込みを送り待ちに積ませない
        let now = try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601)
        let store = SyncBoxMock(
            kinds: kinds, cache: RecordCacheMock(),
            state: SyncState(
                afterSequence: 0, hasCompletedInitialPull: true, readableKinds: kinds.names,
                startedOn: Self.startedOn))
        let client = NuToriAPIClient(
            serverURL: try #require(URL(string: "https://api.example")),
            transport: server,
            appBuildGate: .sample,
            sessionToken: { FakeSyncServer.sessionToken }
        )
        let errorReporting = ErrorReportingSessionMock.ok()
        let mealPhotos = MealPhotos.fixture()
        let weightHealthExport = WeightHealthExportMock.ok()
        let reflection = RecordSyncReflectionMock.ok()
        let account = SignedInAccount(
            accountId: FakeSyncServer.accountId, appleUserId: "apple-user-1")
        self.clock = clock
        self.server = server
        self.store = store
        self.reflection = reflection
        recordSync = RecordSync(
            store: store,
            engines: SyncEngineSourceMock.ok(accountId: account.accountId) { accountId in
                SyncEngine(
                    store: store,
                    client: client,
                    accountId: accountId,
                    device: SyncDevice(
                        deviceId: UUID(), appVersion: "1.0.0", osVersion: "26.0"),
                    timeZone: { tokyo },
                    now: { now },
                    readableKinds: kinds.names,
                    errorReporting: errorReporting,
                    weightHealthExport: weightHealthExport,
                    nutritionHealthExport: NutritionHealthExportMock.ok(),
                    mealPhotos: mealPhotos
                )
            },
            clock: RecordSyncClock(now: { now }, monotonicNow: clock.now, wait: clock.wait),
            watchReply: { try await client.watchReply(sentTextId: $0) },
            reflection: reflection,
            accountSession: AccountDevice(
                log: CallLog(),
                keychain: .ok(token: FakeSyncServer.sessionToken),
                deviceStore: .ok(account: account),
                syncStore: store,
                appleCredentials: .ok(),
                backgroundTransfers: .ok(),
                healthAnchors: .ok(),
                analytics: .ok(log: CallLog()),
                errorReporting: errorReporting
            ).session(),
            missedWeightRecordWatch: MissedWeightRecordWatch(
                cache: store,
                center: MissedWeightRecordReminderCenterMock.ok(),
                timeZone: { tokyo },
                now: { now },
                errorReporting: errorReporting
            ),
            mealPhotos: mealPhotos,
            errorReporting: errorReporting,
            weightHealthExport: weightHealthExport,
            importHealthChanges: {},
            takeStoreRecoveries: { [] }
        )
    }

    /// 時計を進め、終えた同期が `count` 回になるまで待つ
    func advance(by duration: Duration, untilFinishedSyncs count: Int) async {
        await clock.advance(by: duration)
        await reflection.finishedSyncs.reaches(count)
    }
}
