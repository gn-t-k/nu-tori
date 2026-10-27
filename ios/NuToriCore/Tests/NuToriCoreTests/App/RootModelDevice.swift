import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import OpenAPIRuntime
import Testing

/// 初回の取得を終えてサインインし、利用状況を送るをオンにした端末の、アプリの流れ。
/// 偽の同期サーバーにつなぎ、今は日本時間の 2026-09-22 07:00（記録忘れの通知の時刻より前）。時計はテストが進める
@MainActor
struct RootModelDevice {
    nonisolated static let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    let clock: SteppingClock
    let store: SyncBoxMock<RecordCacheMock>
    let analytics: AnalyticsSessionMock
    let log: CallLog
    let reflector: RecordSyncReflector
    let model: RootModel
    /// 目標の設定の流れを作った回数
    let madeGoalSetupFlows: Tally

    /// - Parameters:
    ///   - seed: 開く前にキャッシュに置く記録。目標は、知らせを出させないよう維持の目標を1つ置いてある
    ///   - termsAgreementRequired: 開いたときに、規約への同意が要るとサーバーが答えるか
    init(
        scenario: FakeSyncServer.Scenario = .init(records: [], startedOn: "2026-09-22"),
        termsAgreementRequired: Bool = false,
        seed: (RecordCacheMock) throws -> Void = { _ in }
    ) throws {
        let clock = SteppingClock()
        let kinds = RecordKindRegistry<RecordCacheMock>.ok()
        let now = try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601)
        let cache = RecordCacheMock()
        cache.goalCache.upsert(try .maintaining())
        cache.accountSettingsCache.write(.fixture(sendsUsageData: true))
        try seed(cache)
        let store = SyncBoxMock(
            kinds: kinds, cache: cache,
            state: SyncState(
                afterSequence: 0, hasCompletedInitialPull: true, readableKinds: kinds.names,
                startedOn: scenario.startedOn))
        let client = NuToriAPIClient(
            serverURL: try #require(URL(string: "https://api.example")),
            transport: RootModelServer(
                sync: FakeSyncServerProbe.passing(scenario, clock: clock),
                terms: .termsAgreement(
                    agreementRequired: termsAgreementRequired, termsVersion: "1")),
            appBuildGate: .sample,
            sessionToken: { FakeSyncServer.sessionToken }
        )
        let log = CallLog()
        let analytics = AnalyticsSessionMock.ok(log: log)
        let errorReporting = ErrorReportingSessionMock.ok()
        let mealPhotos = MealPhotos.fixture()
        let healthStore = HealthStoreMock.ok()
        let healthEngine = HealthSyncEngine.fixture(
            healthStore: healthStore, store: store, now: { now })
        let health = HealthSyncSession(
            engine: healthEngine,
            store: healthStore,
            startBackgroundDelivery: { _ in })
        let account = SignedInAccount(
            accountId: FakeSyncServer.accountId, appleUserId: "apple-user-1")
        let accountSession = AccountSession(
            client: client,
            keychain: SessionKeychainMock.ok(token: FakeSyncServer.sessionToken),
            deviceStore: SignInDeviceStoreMock.ok(account: account),
            syncStore: store,
            appleCredentials: AppleCredentialCheckerMock.ok(),
            backgroundTransfers: BackgroundTransferStoreMock.ok(),
            healthAnchors: HealthAnchorStoreMock.ok(),
            analytics: analytics,
            errorReporting: errorReporting,
            timeZone: { Self.tokyo },
            analyticsFlushTimeout: .milliseconds(50)
        )
        let missedWeightRecordWatch = MissedWeightRecordWatch(
            cache: store,
            center: MissedWeightRecordReminderCenterMock.ok(),
            timeZone: { Self.tokyo },
            now: { now },
            errorReporting: errorReporting
        )
        let reflector = RecordSyncReflector()
        let recordSync = RecordSync(
            store: store,
            engines: SyncEngineSourceMock.ok(accountId: account.accountId) { accountId in
                SyncEngine(
                    store: store,
                    client: client,
                    accountId: accountId,
                    device: SyncDevice(deviceId: UUID(), appVersion: "1.0.0", osVersion: "26.0"),
                    timeZone: { Self.tokyo },
                    now: { now },
                    readableKinds: kinds.names,
                    errorReporting: errorReporting,
                    weightHealthExport: healthEngine,
                    nutritionHealthExport: NutritionHealthExportMock.ok(),
                    mealPhotos: mealPhotos
                )
            },
            clock: RecordSyncClock(now: { now }, monotonicNow: clock.now, wait: clock.wait),
            watchReply: { try await client.watchReply(sentTextId: $0) },
            reflection: reflector,
            accountSession: accountSession,
            missedWeightRecordWatch: missedWeightRecordWatch,
            goalSetupNoticeKeeper: GoalSetupNoticeKeeper(
                cache: store, timeZone: { Self.tokyo }, now: { now },
                errorReporting: errorReporting),
            mealPhotos: mealPhotos,
            errorReporting: errorReporting,
            weightHealthExport: healthEngine,
            importHealthChanges: {},
            takeStoreRecoveries: { [] }
        )
        let madeGoalSetupFlows = Tally()
        let deviceClock = DeviceClock(now: { now }, timeZone: { Self.tokyo })
        self.clock = clock
        self.store = store
        self.analytics = analytics
        self.log = log
        self.reflector = reflector
        self.madeGoalSetupFlows = madeGoalSetupFlows
        model = RootModel(
            accountSession: accountSession,
            recordSync: recordSync,
            reflector: reflector,
            health: health,
            missedWeightRecordWatch: missedWeightRecordWatch,
            goalSetup: GoalSetupSession(
                today: deviceClock.today,
                start: { try await recordSync.goalSetupStart(today: $0) },
                makeFlow: { start in
                    madeGoalSetupFlows.add()
                    return GoalSetupFlowHarness(start: start, answers: [:]).flow
                }),
            termsAgreement: TermsAgreementPrompt(client: client, analytics: analytics),
            subscriptionPurchases: .fixture(store: .ok(), transport: .ok(status: .notFound)),
            clock: deviceClock
        )
    }

    /// 同期の段取りが、書き込みを受け付けなかったと知らせる
    func reject(_ record: RejectedWrite.Record) async {
        await reflector.writesRejected([
            RejectedWrite(writeId: UUID(), reason: .outOfRange, record: record)
        ])
    }
}

/// 規約への同意の要求には差し替えが、ほかの要求には偽の同期サーバーが答える
private struct RootModelServer: ClientTransport {
    let sync: FakeSyncServerProbe
    let terms: ClientTransportMock

    func send(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if request.path?.hasPrefix("/v1/terms-agreement") == true {
            return try await terms.send(
                request, body: body, baseURL: baseURL, operationID: operationID)
        }
        return try await sync.send(
            request, body: body, baseURL: baseURL, operationID: operationID)
    }
}
