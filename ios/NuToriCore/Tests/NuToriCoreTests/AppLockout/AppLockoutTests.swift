import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@MainActor
@Suite("締め出しの記憶")
struct AppLockoutTests {
    @MainActor
    @Suite("締め出されたことを覚えていないとき")
    struct NotRemembered {
        let store: AppLockoutStoreMock
        let lockout: AppLockout

        init() {
            store = .ok(lockedOutBuild: nil)
            lockout = AppLockout(currentBuild: 41, store: store)
        }

        @Test("締め出されていない状態で始まること")
        func startsUnlocked() {
            #expect(!lockout.isLockedOut)
        }

        @MainActor
        @Suite("サーバーが 426 を返したとき")
        struct Unsupported {
            let store: AppLockoutStoreMock
            let lockout: AppLockout
            let client: NuToriAPIClient

            init() {
                let store = AppLockoutStoreMock.ok(lockedOutBuild: nil)
                let lockout = AppLockout(currentBuild: 41, store: store)
                self.store = store
                self.lockout = lockout
                client = .lockoutFixture(
                    transport: .ok(status: HTTPResponse.Status(code: 426)), lockout: lockout)
            }

            @Test("締め出された状態になること")
            func locksOut() async {
                _ = try? await client.deleteAccount()

                #expect(lockout.isLockedOut)
            }

            @Test("今のビルド番号と一緒に覚えること")
            func remembersBuild() async {
                _ = try? await client.deleteAccount()

                #expect(store.build == 41)
            }
        }
    }

    @MainActor
    @Suite("今と同じビルド番号で締め出されたことを覚えているとき")
    struct RememberedSameBuild {
        let store: AppLockoutStoreMock
        let lockout: AppLockout

        init() {
            store = .ok(lockedOutBuild: 41)
            lockout = AppLockout(currentBuild: 41, store: store)
        }

        @Test("要求を待たずに、締め出された状態で始まること")
        func startsLockedOut() {
            #expect(lockout.isLockedOut)
        }

        @MainActor
        @Suite("サーバーが 426 でない応答を返したとき")
        struct Supported {
            let store: AppLockoutStoreMock
            let lockout: AppLockout
            let client: NuToriAPIClient

            init() {
                let store = AppLockoutStoreMock.ok(lockedOutBuild: 41)
                let lockout = AppLockout(currentBuild: 41, store: store)
                self.store = store
                self.lockout = lockout
                client = .lockoutFixture(transport: .ok(status: .noContent), lockout: lockout)
            }

            @Test("締め出されていない状態に戻ること")
            func unlocks() async throws {
                _ = try await client.deleteAccount()

                #expect(!lockout.isLockedOut)
            }

            @Test("覚えていたことを忘れること")
            func forgets() async throws {
                _ = try await client.deleteAccount()

                #expect(store.build == nil)
            }
        }

        @MainActor
        @Suite("要求が届かなかったとき")
        struct Unreachable {
            let lockout: AppLockout
            let client: NuToriAPIClient

            init() {
                let lockout = AppLockout(
                    currentBuild: 41, store: AppLockoutStoreMock.ok(lockedOutBuild: 41))
                self.lockout = lockout
                client = .lockoutFixture(
                    transport: .error(URLError(.notConnectedToInternet)), lockout: lockout)
            }

            @Test("締め出された状態のままでいること")
            func staysLockedOut() async {
                _ = try? await client.deleteAccount()

                #expect(lockout.isLockedOut)
            }
        }
    }

    @MainActor
    @Suite("前のビルド番号で締め出されたことを覚えているとき")
    struct RememberedOtherBuild {
        let store: AppLockoutStoreMock
        let lockout: AppLockout

        init() {
            store = .ok(lockedOutBuild: 41)
            lockout = AppLockout(currentBuild: 42, store: store)
        }

        @Test("締め出されていない状態で始まること")
        func startsUnlocked() {
            #expect(!lockout.isLockedOut)
        }

        @Test("覚えていたことを忘れること")
        func forgets() {
            #expect(store.build == nil)
        }
    }
}

extension NuToriAPIClient {
    @MainActor
    fileprivate static func lockoutFixture(
        transport: ClientTransportMock, lockout: AppLockout
    ) -> NuToriAPIClient {
        NuToriAPIClient(
            serverURL: URL(string: "https://api.example")!,
            transport: transport,
            appBuildGate: AppBuildGate(build: 41) { await lockout.receive($0) },
            sessionToken: { "session-1" }
        )
    }
}
