import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

struct AccountDevice {
    static let previousAccount = SignedInAccount(
        accountId: "account-1", appleUserId: "apple-user-1")
    static let seededSettings = AccountSettings.fixture(sendsUsageData: true)
    static let seededHealthState = HealthSyncState(
        anchor: HealthAnchor(data: Data([0x01])),
        hasWrittenCachedManualRecords: true
    )

    let log: CallLog
    let keychain: SessionKeychainMock
    let deviceStore: SignInDeviceStoreMock
    let syncStore: MemoryStore
    let appleCredentials: AppleCredentialCheckerMock
    let backgroundTransfers: BackgroundTransferStoreMock
    let healthAnchors: HealthAnchorStoreMock
    let analytics: AnalyticsSessionMock
    let errorReporting: ErrorReportingSessionMock

    static func signedIn(
        hasOpenedBefore: Bool = true,
        pendingWrites: [PendingWrite] = [],
        hasCompletedInitialPull: Bool = true,
        appleCredentials: AppleCredentialCheckerMock = .ok(),
        analytics: (CallLog) -> AnalyticsSessionMock = { .ok(log: $0) },
        log: CallLog = CallLog()
    ) throws -> AccountDevice {
        AccountDevice(
            log: log,
            keychain: .ok(token: "session-1", log: log),
            deviceStore: .ok(
                hasOpenedBefore: hasOpenedBefore, account: previousAccount, log: log),
            syncStore: .ok(
                records: [try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")],
                accountSettings: seededSettings,
                pendingWrites: pendingWrites,
                state: .fixture(
                    afterSequence: 12, hasCompletedInitialPull: hasCompletedInitialPull),
                healthState: seededHealthState
            ),
            appleCredentials: appleCredentials,
            backgroundTransfers: .ok(),
            healthAnchors: .ok(),
            analytics: analytics(log),
            errorReporting: .ok()
        )
    }

    static func signedOut(
        hasOpenedBefore: Bool = true,
        hasSignInAgainMark: Bool = false,
        pendingWrites: [PendingWrite] = [],
        log: CallLog = CallLog()
    ) -> AccountDevice {
        AccountDevice(
            log: log,
            keychain: .ok(token: nil, log: log),
            deviceStore: .ok(
                hasOpenedBefore: hasOpenedBefore,
                account: nil,
                hasSignInAgainMark: hasSignInAgainMark,
                log: log
            ),
            syncStore: .ok(pendingWrites: pendingWrites),
            appleCredentials: .ok(),
            backgroundTransfers: .ok(),
            healthAnchors: .ok(),
            analytics: .ok(log: log),
            errorReporting: .ok()
        )
    }

    func session(transport: ClientTransportMock = .account()) -> AccountSession {
        AccountSession(
            client: NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                sessionToken: { "session-1" }
            ),
            keychain: keychain,
            deviceStore: deviceStore,
            syncStore: syncStore,
            appleCredentials: appleCredentials,
            backgroundTransfers: backgroundTransfers,
            healthAnchors: healthAnchors,
            analytics: analytics,
            errorReporting: errorReporting,
            timeZone: { TimeZone(identifier: "Asia/Tokyo")! },
            analyticsFlushTimeout: .milliseconds(50)
        )
    }

    var remainingItems: [String] {
        var remaining: [String] = []
        if !syncStore.records.isEmpty { remaining.append("キャッシュの記録") }
        if syncStore.settings != nil { remaining.append("アカウントの設定") }
        if !syncStore.pending.isEmpty { remaining.append("送り待ち") }
        if syncStore.state != nil { remaining.append("同期の状態") }
        if syncStore.healthState != .initial { remaining.append("ヘルスケアの同期の進み具合") }
        if backgroundTransfers.cancelAndDeleteCount == 0 { remaining.append("バックグラウンドの送信") }
        if keychain.token != nil { remaining.append("セッション") }
        if deviceStore.account != nil { remaining.append("アカウント ID と Apple の識別子") }
        if healthAnchors.deleteCount == 0 { remaining.append("ヘルスケアのアンカー") }
        if !deviceStore.didEraseAccountBoundState { remaining.append("端末 ID") }
        if deviceStore.hasMark { remaining.append("サインインし直しの印") }
        return remaining
    }
}

extension AccountDevice {
    func expectNothingErased() {
        #expect(syncStore.eraseAllCount == 0)
        #expect(syncStore.records.count == 1)
        #expect(syncStore.settings == AccountDevice.seededSettings)
        #expect(syncStore.pending.count == 1)
        #expect(syncStore.healthState == AccountDevice.seededHealthState)
        #expect(keychain.token == "session-1")
        #expect(deviceStore.account == AccountDevice.previousAccount)
        #expect(backgroundTransfers.cancelAndDeleteCount == 0)
        #expect(healthAnchors.deleteCount == 0)
        #expect(!deviceStore.didEraseAccountBoundState)
        #expect(analytics.resetCount == 0)
        #expect(errorReporting.clearUserCount == 0)
    }
}

extension AppleSignInCredential {
    static func fixture() -> AppleSignInCredential {
        AppleSignInCredential(
            idToken: "id-token",
            nonce: "nonce-1",
            authorizationCode: "auth-code",
            appleUserId: "apple-user-2"
        )
    }
}

extension PendingWrite {
    static func fixtureCreating() throws -> PendingWrite {
        .creating(try .manual(72.0, at: "2026-09-25T07:00:00+09:00", in: "Asia/Tokyo"))
    }
}
