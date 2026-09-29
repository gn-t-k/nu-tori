public import Foundation
public import NuToriAPI
import OpenAPIRuntime

public actor AccountSession {
    public init(
        client: NuToriAPIClient,
        keychain: any SessionKeychain,
        deviceStore: any SignInDeviceStore,
        syncStore: any SyncStore,
        appleCredentials: any AppleCredentialChecker,
        backgroundTransfers: any BackgroundTransferStore,
        healthAnchors: any HealthAnchorStore,
        analytics: any AnalyticsSession,
        errorReporting: any ErrorReportingSession,
        timeZone: @escaping @Sendable () -> TimeZone,
        analyticsFlushTimeout: Duration
    ) {
        self.client = client
        self.keychain = keychain
        self.deviceStore = deviceStore
        self.syncStore = syncStore
        self.appleCredentials = appleCredentials
        self.backgroundTransfers = backgroundTransfers
        self.healthAnchors = healthAnchors
        self.analytics = analytics
        self.errorReporting = errorReporting
        self.timeZone = timeZone
        self.analyticsFlushTimeout = analyticsFlushTimeout
    }

    public func destinationOnOpen() async throws -> SignInDestination {
        if try await !deviceStore.hasOpenedBefore() {
            try await keychain.deleteSessionToken()
            try await deviceStore.markOpened()
        }
        guard try await keychain.sessionToken() != nil else {
            return try await signInDestinationWithoutSession()
        }
        guard let account = try await deviceStore.signedInAccount() else {
            return try await discardSessionAndAskToSignInAgain()
        }
        switch try await credentialState(of: account) {
        case .revoked, .notFound:
            return try await discardSessionAndAskToSignInAgain()
        case .authorized, .transferred, nil:
            return try await timelineDestination()
        }
    }

    /// 同期の結果から、サインインの画面を出すかを決める。電波が無くてセッションを更新できないだけのときは出さない
    public func destination(afterSync result: SyncResult) async throws -> SignInDestination {
        switch result.ending {
        case .stopped(.sessionExpired):
            return try await discardSessionAndAskToSignInAgain()
        case .finished, .stopped(.rateLimited), .stopped(.unavailable), .stopped(.badRequest):
            return try await timelineDestination()
        }
    }

    public func signIn(with credential: AppleSignInCredential) async throws -> SignInOutcome {
        let result: NuToriAPIClient.StartSessionResult
        do {
            result = try await client.startSession(
                idToken: credential.idToken,
                nonce: credential.nonce,
                authorizationCode: credential.authorizationCode,
                timeZone: timeZone()
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .failed(error.isInternetUnreachable ? .unreachable : .other)
        }
        switch result {
        case .rejected:
            return .failed(.other)
        case .started(let sessionToken, let accountId):
            let account = SignedInAccount(accountId: accountId, appleUserId: credential.appleUserId)
            if try await deviceStore.signedInAccount()?.accountId != accountId {
                try await eraseAccountData()
            }
            try await keychain.save(sessionToken: sessionToken)
            try await deviceStore.save(account)
            try await deviceStore.clearSignInAgainMark()
            return .signedIn(try await timelineDestination())
        }
    }

    /// 消せなかったときは、端末では何も消さない
    public func deleteAccount() async throws -> DeleteAccountOutcome {
        await flushAnalyticsEvents()
        let result: NuToriAPIClient.DeleteAccountResult
        do {
            result = try await client.deleteAccount()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return error.isInternetUnreachable ? .unreachable : .retryLater
        }
        switch result {
        case .deleted:
            try await eraseAccountData()
            return .deleted
        case .sessionExpired:
            return .signInRequired(try await discardSessionAndAskToSignInAgain())
        case .rateLimited:
            return .retryLater
        }
    }

    public enum SignInOutcome: Sendable, Equatable {
        case signedIn(SignInDestination)
        case failed(FailureReason)

        public enum FailureReason: Sendable, Equatable {
            /// 電波が無いときと時間切れ
            case unreachable
            /// Apple の画面の失敗、サーバーが受け付けなかったとき、サーバーの失敗
            case other
        }
    }

    public enum DeleteAccountOutcome: Sendable, Equatable {
        /// 端末から消すものも消した。サインインの画面（説明のひとことの版）に置き換える
        case deleted
        /// 電波が無いときと時間切れ
        case unreachable
        /// 回数の歯止め（429）とサーバーの失敗
        case retryLater
        /// サーバーがセッションを受け付けなかった
        case signInRequired(SignInDestination)
    }

    private let client: NuToriAPIClient
    private let keychain: any SessionKeychain
    private let deviceStore: any SignInDeviceStore
    private let syncStore: any SyncStore
    private let appleCredentials: any AppleCredentialChecker
    private let backgroundTransfers: any BackgroundTransferStore
    private let healthAnchors: any HealthAnchorStore
    private let analytics: any AnalyticsSession
    private let errorReporting: any ErrorReportingSession
    private let timeZone: @Sendable () -> TimeZone
    private let analyticsFlushTimeout: Duration

    private func credentialState(of account: SignedInAccount) async throws
        -> AppleCredentialState?
    {
        do {
            return try await appleCredentials.credentialState(
                forAppleUserId: account.appleUserId)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    private func signInDestinationWithoutSession() async throws -> SignInDestination {
        if try await deviceStore.hasSignInAgainMark() {
            return try await signInAgainDestination()
        }
        return .signIn(.introduction)
    }

    private func signInAgainDestination() async throws -> SignInDestination {
        let pendingWrites = try await syncStore.pendingWrites()
        return .signIn(.signInAgain(hasPendingWrites: !pendingWrites.isEmpty))
    }

    private func timelineDestination() async throws -> SignInDestination {
        let hasCompletedInitialPull = try await syncStore.syncState()?.hasCompletedInitialPull
        return hasCompletedInitialPull == true ? .timeline : .loadingTimeline
    }

    private func discardSessionAndAskToSignInAgain() async throws -> SignInDestination {
        try await keychain.deleteSessionToken()
        try await deviceStore.setSignInAgainMark()
        await analytics.reset()
        await errorReporting.clearUser()
        return try await signInAgainDestination()
    }

    /// セッションを先に消し、アカウント ID は最後に消す。途中で失敗しても、次のサインインで残りを消せる
    private func eraseAccountData() async throws {
        try await keychain.deleteSessionToken()
        try await backgroundTransfers.cancelAndDeleteAll()
        try await syncStore.eraseAll()
        try await healthAnchors.deleteAll()
        try await deviceStore.eraseAccountBoundState()
        await analytics.reset()
        await errorReporting.clearUser()
    }

    private func flushAnalyticsEvents() async {
        let analytics = analytics
        let timeout = analyticsFlushTimeout
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await analytics.flushPendingEvents() }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
        }
    }
}

extension Error {
    fileprivate var isInternetUnreachable: Bool {
        switch self {
        case let error as ClientError:
            return error.underlyingError.isInternetUnreachable
        case let error as URLError:
            let unreachableCodes: Set<URLError.Code> = [
                .notConnectedToInternet, .timedOut, .networkConnectionLost,
                .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                .dataNotAllowed, .internationalRoamingOff, .callIsActive,
            ]
            return unreachableCodes.contains(error.code)
        default:
            return false
        }
    }
}
