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

        @Suite("セッションが無いとき")
        struct WithoutSession {
            @Test("サインインし直しの印が無ければ、説明のひとことの版にすること")
            func showsIntroductionWithoutMark() async throws {
                let device = AccountDevice.signedOut()

                let destination = try await device.session().destinationOnOpen()

                #expect(destination == .signIn(.introduction))
            }

            @Test("サインインし直しの印があれば、送り待ちが無いときの1行の版にすること")
            func showsSignInAgainWithoutPendingWrites() async throws {
                let device = AccountDevice.signedOut(hasSignInAgainMark: true)

                let destination = try await device.session().destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: false)))
            }

            @Test("サインインし直しの印があり送り待ちもあれば、送り待ちがあるときの1行の版にすること")
            func showsSignInAgainWithPendingWrites() async throws {
                let device = try AccountDevice.signedOut(
                    hasSignInAgainMark: true, pendingWrites: [.fixtureCreating()])

                let destination = try await device.session().destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: true)))
            }
        }

        @Suite("セッションがあって Apple の資格情報が有効なとき")
        struct WithValidCredential {
            @Test("初回の取得を終えていれば、タイムラインにすること")
            func showsTimeline() async throws {
                let device = try AccountDevice.signedIn(hasCompletedInitialPull: true)

                let destination = try await device.session().destinationOnOpen()

                #expect(destination == .timeline)
                #expect(device.appleCredentials.checkedAppleUserIds == ["apple-user-1"])
            }

            @Test("初回の取得を終えていなければ、読み込み中のタイムラインにすること")
            func showsLoadingTimeline() async throws {
                let device = try AccountDevice.signedIn(hasCompletedInitialPull: false)

                let destination = try await device.session().destinationOnOpen()

                #expect(destination == .loadingTimeline)
            }
        }

        @Suite("Apple の資格情報が取り消されているとき")
        struct WithRevokedCredential {
            @Test("revoked なら、セッションを捨て、印を残し、観測の送り先を外して、サインインし直しの画面にすること")
            func discardsSessionOnRevoked() async throws {
                let device = try AccountDevice.signedIn(
                    pendingWrites: [.fixtureCreating()], appleCredentials: .ok(.revoked))

                let destination = try await device.session().destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: true)))
                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.hasMark)
                #expect(device.analytics.resetCount == 1)
                #expect(device.errorReporting.clearUserCount == 1)
                #expect(device.syncStore.pending.count == 1)
            }

            @Test("notFound でも、サインインし直しの画面にすること")
            func discardsSessionOnNotFound() async throws {
                let device = try AccountDevice.signedIn(appleCredentials: .ok(.notFound))

                let destination = try await device.session().destinationOnOpen()

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: false)))
                #expect(device.keychain.token == nil)
            }
        }

        @Suite("Apple の資格情報を確かめられないとき")
        struct WithUnverifiableCredential {
            @Test("電波が無くて確かめられなければ、セッションを残してタイムラインにすること")
            func keepsSession() async throws {
                let device = try AccountDevice.signedIn(
                    appleCredentials: .error(URLError(.notConnectedToInternet)))

                let destination = try await device.session().destinationOnOpen()

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
            @Test("セッションを捨て、印を残し、送り待ちは残して、サインインし直しの画面にすること")
            func discardsSession() async throws {
                let device = try AccountDevice.signedIn(pendingWrites: [.fixtureCreating()])
                let result = SyncResult(rejectedWrites: [], ending: .stopped(.sessionExpired))

                let destination = try await device.session().destination(afterSync: result)

                #expect(destination == .signIn(.signInAgain(hasPendingWrites: true)))
                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.hasMark)
                #expect(device.syncStore.pending.count == 1)
            }
        }

        @Suite("電波が無くて更新できなかったとき")
        struct Unavailable {
            @Test("サインインの画面を出さず、セッションも印も変えないこと")
            func keepsSession() async throws {
                let device = try AccountDevice.signedIn()
                let result = SyncResult(rejectedWrites: [], ending: .stopped(.unavailable))

                let destination = try await device.session().destination(afterSync: result)

                #expect(destination == .timeline)
                #expect(device.keychain.token == "session-1")
                #expect(!device.deviceStore.hasMark)
            }
        }
    }

    @Suite("サインインしたとき")
    struct SigningIn {
        static let credential = AppleSignInCredential(
            idToken: "id-token",
            nonce: "nonce-1",
            authorizationCode: "auth-code",
            appleUserId: "apple-user-2"
        )

        @Suite("この端末に保存したアカウントが無いとき")
        struct WithoutSavedAccount {
            let device: AccountDevice
            let transport: ClientTransportMock
            let session: AccountSession

            init() {
                device = .signedOut(hasSignInAgainMark: true)
                transport = .account(accountId: "account-2")
                session = device.session(transport: transport)
            }

            @Test("端末から消すものを消してから、新しいセッションとアカウントを保存すること")
            func erasesThenSaves() async throws {
                _ = try await session.signIn(with: SigningIn.credential)

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
                let outcome = try await session.signIn(with: SigningIn.credential)

                #expect(outcome == .signedIn(.loadingTimeline))
                #expect(!device.deviceStore.hasMark)
            }

            @Test("Apple から得た値と端末のタイムゾーンを、セッションを作る経路に送ること")
            func sendsCredentialAndTimeZone() async throws {
                _ = try await session.signIn(with: SigningIn.credential)

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
            let session: AccountSession

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .account(accountId: "account-2"))
            }

            @Test("前のアカウントのものを端末からすべて消し、新しいものを保存すること")
            func erasesPreviousAccountData() async throws {
                _ = try await session.signIn(with: SigningIn.credential)

                #expect(device.syncStore.records.isEmpty)
                #expect(device.syncStore.pending.isEmpty)
                #expect(device.syncStore.state == nil)
                #expect(device.backgroundTransfers.cancelAndDeleteCount == 1)
                #expect(device.healthAnchors.deleteCount == 1)
                #expect(device.deviceStore.didEraseAccountBoundState)
                #expect(device.keychain.token == "session-2")
                #expect(device.deviceStore.account?.accountId == "account-2")
            }

            @Test("観測の送り先を外すこと")
            func resetsObservation() async throws {
                _ = try await session.signIn(with: SigningIn.credential)

                #expect(device.analytics.resetCount == 1)
                #expect(device.errorReporting.clearUserCount == 1)
            }
        }

        @Suite("前のアカウントと同じアカウントのとき")
        struct WithSameAccount {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(pendingWrites: [.fixtureCreating()])
                session = device.session(transport: .account(accountId: "account-1"))
            }

            @Test("端末のものを消さず、新しいセッションだけ保存すること")
            func keepsData() async throws {
                _ = try await session.signIn(with: SigningIn.credential)

                #expect(device.syncStore.eraseAllCount == 0)
                #expect(device.syncStore.records.count == 1)
                #expect(device.syncStore.pending.count == 1)
                #expect(!device.deviceStore.didEraseAccountBoundState)
                #expect(device.keychain.token == "session-2")
            }

            @Test("初回の取得を終えていれば、タイムラインにすること")
            func showsTimeline() async throws {
                let outcome = try await session.signIn(with: SigningIn.credential)

                #expect(outcome == .signedIn(.timeline))
            }

            @Test("Apple の識別子を、新しく得たものに置き換えること")
            func replacesAppleUserId() async throws {
                _ = try await session.signIn(with: SigningIn.credential)

                #expect(device.deviceStore.account?.appleUserId == "apple-user-2")
            }
        }

        @Suite("サインインし直しの印があるとき")
        struct WithSignInAgainMark {
            @Test("同じアカウントでサインインできたら、印を消すこと")
            func clearsMark() async throws {
                let device = try AccountDevice.signedIn()
                try await device.deviceStore.setSignInAgainMark()

                _ = try await device.session().signIn(with: SigningIn.credential)

                #expect(!device.deviceStore.hasMark)
            }
        }

        @Suite("サインインできなかったとき")
        struct Failing {
            @Test("サーバーがトークンかコードを受け付けなければ、その他の失敗を返し、何も保存しないこと")
            func rejectedByServer() async throws {
                let device = AccountDevice.signedOut(hasSignInAgainMark: true)
                let session = device.session(transport: .account(startStatus: .unauthorized))

                let outcome = try await session.signIn(with: SigningIn.credential)

                #expect(outcome == .failed(.other))
                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.account == nil)
                #expect(device.deviceStore.hasMark)
            }

            @Test("電波が無ければ、つながらない失敗を返し、端末のものを消さないこと")
            func offline() async throws {
                let device = try AccountDevice.signedIn()
                let session = device.session(
                    transport: .error(URLError(.notConnectedToInternet)))

                let outcome = try await session.signIn(with: SigningIn.credential)

                #expect(outcome == .failed(.unreachable))
                #expect(device.syncStore.eraseAllCount == 0)
                #expect(device.keychain.token == "session-1")
            }

            @Test("時間切れでも、つながらない失敗を返すこと")
            func timedOut() async throws {
                let device = AccountDevice.signedOut()
                let session = device.session(transport: .error(URLError(.timedOut)))

                let outcome = try await session.signIn(with: SigningIn.credential)

                #expect(outcome == .failed(.unreachable))
            }

            @Test("サーバーが失敗したら、その他の失敗を返すこと")
            func serverFailure() async throws {
                let device = AccountDevice.signedOut()
                let session = device.session(
                    transport: .account(startStatus: .internalServerError))

                let outcome = try await session.signIn(with: SigningIn.credential)

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
            @Test("諦めて、削除を進めること")
            func givesUpFlushing() async throws {
                let device = try AccountDevice.signedIn(analytics: { .neverFlushes(log: $0) })

                let outcome = try await device.session().deleteAccount()

                #expect(outcome == .deleted)
                #expect(device.analytics.flushCount == 1)
                #expect(device.remainingItems.isEmpty)
            }
        }

        @Suite("削除できなかったとき")
        struct NotDeleted {
            @Test("電波が無ければ、つながらない結果を返し、端末では何も消さないこと")
            func offline() async throws {
                let device = try AccountDevice.signedIn(pendingWrites: [.fixtureCreating()])
                let session = device.session(
                    transport: .error(URLError(.notConnectedToInternet)))

                let outcome = try await session.deleteAccount()

                #expect(outcome == .unreachable)
                NotDeleted.expectNothingErased(device)
            }

            @Test("時間切れでも、つながらない結果を返し、端末では何も消さないこと")
            func timedOut() async throws {
                let device = try AccountDevice.signedIn(pendingWrites: [.fixtureCreating()])
                let session = device.session(transport: .error(URLError(.timedOut)))

                let outcome = try await session.deleteAccount()

                #expect(outcome == .unreachable)
                NotDeleted.expectNothingErased(device)
            }

            @Test("回数の歯止め（429）なら、あとでやり直す結果を返し、端末では何も消さないこと")
            func rateLimited() async throws {
                let device = try AccountDevice.signedIn(pendingWrites: [.fixtureCreating()])
                let session = device.session(transport: .account(deleteStatus: .tooManyRequests))

                let outcome = try await session.deleteAccount()

                #expect(outcome == .retryLater)
                NotDeleted.expectNothingErased(device)
            }

            @Test("サーバーが失敗したら、あとでやり直す結果を返し、端末では何も消さないこと")
            func serverFailure() async throws {
                let device = try AccountDevice.signedIn(pendingWrites: [.fixtureCreating()])
                let session = device.session(
                    transport: .account(deleteStatus: .internalServerError))

                let outcome = try await session.deleteAccount()

                #expect(outcome == .retryLater)
                NotDeleted.expectNothingErased(device)
            }

            @Test("セッションを受け付けなければ、サインインし直しの画面にし、記録と送り待ちは消さないこと")
            func sessionExpired() async throws {
                let device = try AccountDevice.signedIn(pendingWrites: [.fixtureCreating()])
                let session = device.session(transport: .account(deleteStatus: .unauthorized))

                let outcome = try await session.deleteAccount()

                #expect(outcome == .signInRequired(.signIn(.signInAgain(hasPendingWrites: true))))
                #expect(device.keychain.token == nil)
                #expect(device.deviceStore.hasMark)
                #expect(device.syncStore.eraseAllCount == 0)
                #expect(device.syncStore.pending.count == 1)
            }

            private static func expectNothingErased(_ device: AccountDevice) {
                #expect(device.syncStore.eraseAllCount == 0)
                #expect(device.syncStore.records.count == 1)
                #expect(device.syncStore.pending.count == 1)
                #expect(device.keychain.token == "session-1")
                #expect(device.deviceStore.account == AccountDevice.previousAccount)
                #expect(device.backgroundTransfers.cancelAndDeleteCount == 0)
                #expect(device.healthAnchors.deleteCount == 0)
                #expect(!device.deviceStore.didEraseAccountBoundState)
                #expect(device.analytics.resetCount == 0)
                #expect(device.errorReporting.clearUserCount == 0)
            }
        }
    }
}
