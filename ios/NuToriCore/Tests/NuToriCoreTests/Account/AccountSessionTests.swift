import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import Testing

@Suite("アカウントのサインインの状態")
struct AccountSessionTests {
    @Suite("アプリを開いたとき")
    struct OpeningTheApp {
        @Suite("入れ直して初めて開いたとき")
        struct FirstOpenAfterReinstall {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(hasOpenedBefore: false)
                session = device.session()
            }

            @Test("キーチェーンに残ったセッションを捨てて、説明のひとことの版のサインインの画面にすること")
            func discardsSessionAndShowsIntroduction() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .signIn(.introduction))
                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.hasOpened)
            }
        }

        @Suite("セッションが無く、サインインし直しの印も無いとき")
        struct WithoutSessionAndMark {
            let session: AccountSession

            init() {
                session = AccountDevice.signedOut().session()
            }

            @Test("説明のひとことの版のサインインの画面にすること")
            func showsIntroduction() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .signIn(.introduction))
            }
        }

        @Suite("セッションが無く、サインインし直しの印があるとき")
        struct WithoutSessionWithMark {
            let session: AccountSession

            init() {
                session = AccountDevice.signedOut(hasSignInAgainMark: true).session()
            }

            @Test("サインインし直しの1行の版のサインインの画面にすること")
            func showsSignInAgain() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: false)))
            }
        }

        @Suite("セッションが無く、サインインし直しの印も送り待ちもあるとき")
        struct WithoutSessionWithMarkAndPendingWrites {
            let session: AccountSession

            init() throws {
                session = try AccountDevice.signedOut(
                    hasSignInAgainMark: true, pendingWrites: [.fixtureCreating()]
                ).session()
            }

            @Test("送り待ちがあるときの1行の版のサインインの画面にすること")
            func showsSignInAgainWithPendingWrites() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: true)))
            }
        }

        @Suite("セッションがあり、Apple の資格情報が有効で、初回の取得を終えているとき")
        struct WithValidCredentialAndInitialPull {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(hasCompletedInitialPull: true)
                session = device.session()
            }

            @Test("保存した Apple の識別子で確かめ、タイムラインにすること")
            func showsTimeline() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .timeline)
                #expect(device.appleCredentials.checkedAppleUserIds == ["apple-user-1"])
            }
        }

        @Suite("セッションがあり、Apple の資格情報が有効で、初回の取得を終えていないとき")
        struct WithValidCredentialWithoutInitialPull {
            let session: AccountSession

            init() throws {
                session = try AccountDevice.signedIn(hasCompletedInitialPull: false).session()
            }

            @Test("読み込み中のタイムラインにすること")
            func showsLoadingTimeline() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .loadingTimeline)
            }
        }

        @Suite("Apple の資格情報が取り消されているとき")
        struct WithRevokedCredential {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(
                    pendingWrites: [.fixtureCreating()], appleCredentials: .ok(.revoked))
                session = device.session()
            }

            @Test("送り待ちがあるときの、サインインし直しの画面にすること")
            func showsSignInAgain() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: true)))
            }

            @Test("セッションを捨て、印を残し、送り待ちは残すこと")
            func discardsSessionAndKeepsPendingWrites() async throws {
                _ = try await session.destinationOnOpen()

                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.hasMark)
                #expect(device.syncStore.pending.count == 1)
            }

            @Test("PostHog をリセットし、Sentry の user を外すこと")
            func resetsObservation() async throws {
                _ = try await session.destinationOnOpen()

                #expect(device.analytics.resetCount == 1)
                #expect(device.errorReporting.clearUserCount == 1)
            }
        }

        @Suite("Apple の資格情報が見つからないとき")
        struct WithNotFoundCredential {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(appleCredentials: .ok(.notFound))
                session = device.session()
            }

            @Test("セッションを捨てて、サインインし直しの画面にすること")
            func discardsSession() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: false)))
                #expect(device.keychain.token == nil)
            }
        }

        @Suite("電波が無くて Apple の資格情報を確かめられないとき")
        struct WithUnverifiableCredential {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(appleCredentials: .error(URLError(.notConnectedToInternet)))
                session = device.session()
            }

            @Test("タイムラインにし、セッションも印も変えないこと")
            func keepsSession() async throws {
                let destination = try await session.destinationOnOpen()

                #expect(destination == .timeline)
                #expect(device.keychain.token == "session-1")
                #expect(!device.deviceStore.hasMark)
            }
        }
    }

    @Suite("同期の結果を受けたとき")
    struct AfterSync {
        @Suite("サーバーがセッションを受け付けなかったとき")
        struct SessionExpired {
            let device: AccountDevice
            let session: AccountSession
            let result: SyncResult

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session()
                result = SyncResult(rejectedWrites: [], ending: .stopped(.sessionExpired))
            }

            @Test("送り待ちがあるときの、サインインし直しの画面にすること")
            func showsSignInAgain() async throws {
                let destination = try await session.destination(afterSync: result)

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: true)))
            }

            @Test("セッションを捨て、印を残し、送り待ちは残すこと")
            func discardsSessionAndKeepsPendingWrites() async throws {
                _ = try await session.destination(afterSync: result)

                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.hasMark)
                #expect(device.syncStore.pending.count == 1)
            }
        }

        @Suite("電波が無くて更新できなかったとき")
        struct Unavailable {
            let device: AccountDevice
            let session: AccountSession
            let result: SyncResult

            init() throws {
                device = try .signedIn()
                session = device.session()
                result = SyncResult(rejectedWrites: [], ending: .stopped(.unavailable))
            }

            @Test("サインインの画面を出さず、セッションも印も変えないこと")
            func keepsSession() async throws {
                let destination = try await session.destination(afterSync: result)

                #expect(destination == .timeline)
                #expect(device.keychain.token == "session-1")
                #expect(!device.deviceStore.hasMark)
            }
        }
    }

    @Suite("サインインしたとき")
    struct SigningIn {
        @Suite("この端末に保存したアカウントが無いとき")
        struct WithoutSavedAccount {
            let device: AccountDevice
            let transport: ClientTransportMock
            let credential: AppleSignInCredential
            let session: AccountSession

            init() {
                credential = .fixture()
                device = .signedOut(hasSignInAgainMark: true)
                transport = .account(accountId: "account-2")
                session = device.session(transport: transport)
            }

            @Test("端末から消すものを消してから、新しいセッションとアカウントを保存すること")
            func erasesThenSaves() async throws {
                _ = try await session.signIn(with: credential)

                #expect(device.syncStore.eraseAllCount == 1)
                #expect(device.backgroundTransfers.cancelAndDeleteCount == 1)
                #expect(device.healthAnchors.deleteCount == 1)
                #expect(device.deviceStore.didEraseAccountBoundState)
                #expect(device.keychain.token == "session-2")
                #expect(
                    device.deviceStore.account
                        == SignedInAccount(accountId: "account-2", appleUserId: "apple-user-2"))
                let events = device.log.events
                let lastErase = try #require(events.lastIndex(of: "deviceStore.erase"))
                let firstSave = try #require(events.firstIndex(of: "keychain.save"))
                #expect(lastErase < firstSave)
            }

            @Test("印を消し、初回の取得がまだなので読み込み中にすること")
            func clearsMarkAndShowsLoading() async throws {
                let outcome = try await session.signIn(with: credential)

                #expect(outcome == .signedIn(.loadingTimeline))
                #expect(!device.deviceStore.hasMark)
            }

            @Test("Apple から得た値と端末のタイムゾーンを、セッションを作る経路に送ること")
            func sendsCredentialAndTimeZone() async throws {
                _ = try await session.signIn(with: credential)

                let request = try #require(transport.requests.first)
                #expect(request.request.path == "/v1/sessions")
                let body = try JSONDecoder().decode(
                    SessionRequestBody.self, from: Data(try #require(request.body).utf8))
                #expect(body.idToken == "id-token")
                #expect(body.nonce == "nonce-1")
                #expect(body.authorizationCode == "auth-code")
                #expect(body.timeZone == "Asia/Tokyo")
            }
        }

        @Suite("前のアカウントと別のアカウントのとき")
        struct WithDifferentAccount {
            let device: AccountDevice
            let credential: AppleSignInCredential
            let session: AccountSession

            init() throws {
                credential = .fixture()
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .account(accountId: "account-2"))
            }

            @Test("前のアカウントのものを端末からすべて消し、新しいものを保存すること")
            func erasesPreviousAccountData() async throws {
                _ = try await session.signIn(with: credential)

                #expect(device.syncStore.records.isEmpty)
                #expect(device.syncStore.pending.isEmpty)
                #expect(device.syncStore.state == nil)
                #expect(device.backgroundTransfers.cancelAndDeleteCount == 1)
                #expect(device.healthAnchors.deleteCount == 1)
                #expect(device.deviceStore.didEraseAccountBoundState)
                #expect(device.keychain.token == "session-2")
                #expect(device.deviceStore.account?.accountId == "account-2")
            }

            @Test("PostHog をリセットし、Sentry の user を外すこと")
            func resetsObservation() async throws {
                _ = try await session.signIn(with: credential)

                #expect(device.analytics.resetCount == 1)
                #expect(device.errorReporting.clearUserCount == 1)
            }
        }

        @Suite("前のアカウントと同じアカウントで、初回の取得を終えているとき")
        struct WithSameAccount {
            let device: AccountDevice
            let credential: AppleSignInCredential
            let session: AccountSession

            init() throws {
                credential = .fixture()
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .account(accountId: "account-1"))
            }

            @Test("端末のものを消さず、新しいセッションだけ保存すること")
            func keepsData() async throws {
                _ = try await session.signIn(with: credential)

                #expect(device.syncStore.eraseAllCount == 0)
                #expect(device.syncStore.records.count == 1)
                #expect(device.syncStore.pending.count == 1)
                #expect(!device.deviceStore.didEraseAccountBoundState)
                #expect(device.keychain.token == "session-2")
            }

            @Test("タイムラインにすること")
            func showsTimeline() async throws {
                let outcome = try await session.signIn(with: credential)

                #expect(outcome == .signedIn(.timeline))
            }

            @Test("Apple の識別子を、新しく得たものに置き換えること")
            func replacesAppleUserId() async throws {
                _ = try await session.signIn(with: credential)

                #expect(device.deviceStore.account?.appleUserId == "apple-user-2")
            }
        }

        @Suite("同じアカウントで、サインインし直しの印があるとき")
        struct WithSignInAgainMark {
            let device: AccountDevice
            let credential: AppleSignInCredential
            let session: AccountSession

            init() async throws {
                credential = .fixture()
                device = try .signedIn()
                try await device.deviceStore.setSignInAgainMark()
                session = device.session()
            }

            @Test("印を消すこと")
            func clearsMark() async throws {
                _ = try await session.signIn(with: credential)

                #expect(!device.deviceStore.hasMark)
            }
        }

        @Suite("サーバーがトークンかコードを受け付けなかったとき")
        struct RejectedByServer {
            let device: AccountDevice
            let credential: AppleSignInCredential
            let session: AccountSession

            init() {
                credential = .fixture()
                device = .signedOut(hasSignInAgainMark: true)
                session = device.session(transport: .account(startStatus: .unauthorized))
            }

            @Test("その他の失敗を返し、何も保存しないこと")
            func failsWithoutSaving() async throws {
                let outcome = try await session.signIn(with: credential)

                #expect(outcome == .failed(.other))
                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.account == nil)
                #expect(device.deviceStore.hasMark)
            }
        }

        @Suite("電波が無いとき")
        struct Offline {
            let device: AccountDevice
            let credential: AppleSignInCredential
            let session: AccountSession

            init() throws {
                credential = .fixture()
                device = try .signedIn()
                session = device.session(transport: .error(URLError(.notConnectedToInternet)))
            }

            @Test("つながらない失敗を返すこと")
            func failsAsUnreachable() async throws {
                let outcome = try await session.signIn(with: credential)

                #expect(outcome == .failed(.unreachable))
            }

            @Test("端末のものを消さず、セッションも変えないこと")
            func keepsData() async throws {
                _ = try await session.signIn(with: credential)

                #expect(device.syncStore.eraseAllCount == 0)
                #expect(device.keychain.token == "session-1")
            }
        }

        @Suite("時間切れのとき")
        struct TimedOut {
            let credential: AppleSignInCredential
            let session: AccountSession

            init() {
                credential = .fixture()
                session = AccountDevice.signedOut().session(
                    transport: .error(URLError(.timedOut)))
            }

            @Test("つながらない失敗を返すこと")
            func failsAsUnreachable() async throws {
                let outcome = try await session.signIn(with: credential)

                #expect(outcome == .failed(.unreachable))
            }
        }

        @Suite("サーバーが失敗したとき")
        struct ServerFailure {
            let credential: AppleSignInCredential
            let session: AccountSession

            init() {
                credential = .fixture()
                session = AccountDevice.signedOut().session(
                    transport: .account(startStatus: .internalServerError))
            }

            @Test("その他の失敗を返すこと")
            func failsAsOther() async throws {
                let outcome = try await session.signIn(with: credential)

                #expect(outcome == .failed(.other))
            }
        }
    }

    @Suite("アカウントを削除するとき")
    struct DeletingAccount {
        @Suite("削除できたとき")
        struct Deleted {
            let device: AccountDevice
            let session: AccountSession
            let log: CallLog

            init() throws {
                let log = CallLog()
                self.log = log
                device = try .signedIn(pendingWrites: [.fixtureCreating()], log: log)
                session = device.session(
                    transport: .account(onRequest: { log.record("request \($0)") }))
            }

            @Test("PostHog の列を送り切り、削除の経路を呼び、端末から消し、PostHog と Sentry を外す順に進めること")
            func followsTheOrder() async throws {
                let outcome = try await session.deleteAccount()

                #expect(outcome == .deleted)
                let events = log.events
                let flush = try #require(events.firstIndex(of: "analytics.flush"))
                let request = try #require(events.firstIndex(of: "request /v1/account"))
                let erase = try #require(events.firstIndex(of: "deviceStore.erase"))
                let reset = try #require(events.firstIndex(of: "analytics.reset"))
                #expect(flush < request)
                #expect(request < erase)
                #expect(erase < reset)
                #expect(device.errorReporting.clearUserCount == 1)
            }

            @Test("端末から消すものをすべて消すこと")
            func erasesEverything() async throws {
                _ = try await session.deleteAccount()

                #expect(device.remainingItems.isEmpty)
            }

            @Test("そのあと開くと、説明のひとことの版のサインインの画面になること")
            func showsIntroductionAfterwards() async throws {
                _ = try await session.deleteAccount()

                let destination = try await session.destinationOnOpen()

                #expect(destination == .signIn(.introduction))
            }
        }

        @Suite("PostHog の列が送り切れないとき")
        struct AnalyticsNeverFlushes {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(analytics: { .neverFlushes(log: $0) })
                session = device.session()
            }

            @Test("諦めて、削除を進めること")
            func givesUpFlushing() async throws {
                let outcome = try await session.deleteAccount()

                #expect(outcome == .deleted)
                #expect(device.analytics.flushCount == 1)
                #expect(device.remainingItems.isEmpty)
            }
        }

        @Suite("電波が無いとき")
        struct Offline {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .error(URLError(.notConnectedToInternet)))
            }

            @Test("つながらない結果を返すこと")
            func returnsUnreachable() async throws {
                let outcome = try await session.deleteAccount()

                #expect(outcome == .unreachable)
            }

            @Test("端末では何も消さないこと")
            func erasesNothing() async throws {
                _ = try await session.deleteAccount()

                device.expectNothingErased()
            }
        }

        @Suite("時間切れのとき")
        struct TimedOut {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .error(URLError(.timedOut)))
            }

            @Test("つながらない結果を返し、端末では何も消さないこと")
            func returnsUnreachableAndErasesNothing() async throws {
                let outcome = try await session.deleteAccount()

                #expect(outcome == .unreachable)
                device.expectNothingErased()
            }
        }

        @Suite("回数の歯止め（429）にかかったとき")
        struct RateLimited {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .account(deleteStatus: .tooManyRequests))
            }

            @Test("あとでやり直す結果を返し、端末では何も消さないこと")
            func returnsRetryLaterAndErasesNothing() async throws {
                let outcome = try await session.deleteAccount()

                #expect(outcome == .retryLater)
                device.expectNothingErased()
            }
        }

        @Suite("サーバーが失敗したとき")
        struct ServerFailure {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .account(deleteStatus: .internalServerError))
            }

            @Test("あとでやり直す結果を返し、端末では何も消さないこと")
            func returnsRetryLaterAndErasesNothing() async throws {
                let outcome = try await session.deleteAccount()

                #expect(outcome == .retryLater)
                device.expectNothingErased()
            }
        }

        @Suite("サーバーがセッションを受け付けなかったとき")
        struct SessionExpired {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .account(deleteStatus: .unauthorized))
            }

            @Test("送り待ちがあるときの、サインインし直しの画面にすること")
            func returnsSignInRequired() async throws {
                let outcome = try await session.deleteAccount()

                #expect(outcome == .signInRequired(.signIn(.signInAgain(hasPendingWrites: true))))
            }

            @Test("セッションを捨て、印を残し、記録と送り待ちは消さないこと")
            func discardsSessionAndKeepsRecords() async throws {
                _ = try await session.deleteAccount()

                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.hasMark)
                #expect(device.syncStore.eraseAllCount == 0)
                #expect(device.syncStore.pending.count == 1)
            }
        }
    }
}
