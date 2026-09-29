import Foundation
import NuToriAPI
import NuToriCore
import Testing

extension SyncEngineTests {
    @Suite("利用状況の切り替えを保存する")
    struct SaveUsageDataSetting {
        @Suite("切り替えたことがまだ無いとき")
        struct FirstToggle {
            let store: SyncStoreMock
            let engine: SyncEngine

            init() {
                store = .ok()
                engine = .fixture(store: store, transport: .ok())
            }

            @Test("設定を置くのと同じ保存で、直す書き込みを送り待ちに1件足すこと")
            func savesSettingsWithPendingWrite() async throws {
                try await engine.setSendsUsageData(false)

                let settings = AccountSettings.fixture(sendsUsageData: false)
                let pending = try #require(store.pending.first)
                #expect(store.settings == settings)
                #expect(store.pending.count == 1)
                #expect(pending.operation == .updateAccountSettings(settings))
                #expect(pending.enqueuedAt == SyncEngine.fixtureNow)
            }

            @Test("設定の ID を、アカウント ID から出した UUID v5 にすること")
            func derivesIdFromAccountId() async throws {
                try await engine.setSendsUsageData(false)

                let id = try #require(store.settings?.id)
                #expect(id == AccountSettings.id(forAccountId: SyncEngine.fixtureAccountId))
                #expect(id.uuidString.dropFirst(14).first == "5")
            }
        }

        @Suite("続けて切り替えたとき")
        struct ToggleTwice {
            let store: SyncStoreMock
            let engine: SyncEngine

            init() {
                store = .ok()
                engine = .fixture(store: store, transport: .ok())
            }

            @Test("設定は最後の値にし、送り待ちには切り替えごとに書き込みを並べること")
            func keepsLastValueAndEveryWrite() async throws {
                try await engine.setSendsUsageData(false)
                try await engine.setSendsUsageData(true)

                #expect(store.settings == .fixture(sendsUsageData: true))
                #expect(
                    store.pending.map(\.operation) == [
                        .updateAccountSettings(.fixture(sendsUsageData: false)),
                        .updateAccountSettings(.fixture(sendsUsageData: true)),
                    ])
            }
        }
    }

    @Suite("アカウントの設定を送る・取りに行く")
    struct SyncAccountSettings {
        @Suite("切り替えが送り待ちにあるとき")
        struct PendingToggle {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() {
                store = .ok(
                    accountSettings: .fixture(sendsUsageData: false),
                    pendingWrites: [
                        PendingWrite(
                            writeId: UUID(),
                            enqueuedAt: SyncEngine.fixtureNow,
                            operation: .updateAccountSettings(.fixture(sendsUsageData: false))
                        )
                    ]
                )
                transport = .ok()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("記録が無くても、update_account_settings の書き込みとして送り、送り待ちを空にすること")
            func pushesUpdateWrite() async throws {
                let result = try await engine.sync()

                let write = try #require(transport.pushBodies.first?.writes.first)
                #expect(write.type == "update_account_settings")
                #expect(
                    write.accountSettings
                        == .init(
                            id: AccountSettings.id(forAccountId: SyncEngine.fixtureAccountId)
                                .uuidString,
                            sendsUsageData: false
                        ))
                #expect(store.pending.isEmpty)
                #expect(result == SyncResult(rejectedWrites: [], ending: .finished))
            }
        }

        @Suite("サーバーが切り替えを受け付けなかったとき")
        struct RejectedToggle {
            let store: SyncStoreMock
            let engine: SyncEngine

            init() {
                store = .ok(
                    accountSettings: .fixture(sendsUsageData: false),
                    pendingWrites: [
                        PendingWrite(
                            writeId: UUID(),
                            enqueuedAt: SyncEngine.fixtureNow,
                            operation: .updateAccountSettings(.fixture(sendsUsageData: false))
                        )
                    ]
                )
                engine = .fixture(store: store, transport: .ok(rejectedWriteIndexes: [0]))
            }

            @Test("送り待ちから外し、設定は変えず、受け付けなかった記録として返さないこと")
            func dropsWriteQuietly() async throws {
                let result = try await engine.sync()

                #expect(store.pending.isEmpty)
                #expect(store.settings == .fixture(sendsUsageData: false))
                #expect(result == SyncResult(rejectedWrites: [], ending: .finished))
            }
        }

        @Suite("設定の記録が届いたとき")
        struct PulledSettings {
            let store: SyncStoreMock
            let engine: SyncEngine
            let settingsId: String

            init() {
                settingsId =
                    AccountSettings.id(forAccountId: SyncEngine.fixtureAccountId).uuidString
                store = .ok(accountSettings: .fixture(sendsUsageData: true))
                engine = .fixture(
                    store: store,
                    transport: .ok(pullPages: [
                        """
                        {"changes":[
                          {"sequence":7,"kind":"account_settings","recordId":"\(settingsId)",
                           "record":{"id":"\(settingsId)","sendsUsageData":false}},
                          {"sequence":8,"kind":"account_settings","recordId":"\(settingsId)",
                           "record":{"id":"\(settingsId)","sendsUsageData":true}},
                          {"sequence":9,"kind":"account_settings","recordId":"\(settingsId)",
                           "record":{"id":"\(settingsId)","sendsUsageData":false}}
                        ],"hasMore":false,"nextAfterSequence":9,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("いちばん新しいものでキャッシュを置き換え、通し番号を進めること")
            func replacesCacheWithLatest() async throws {
                _ = try await engine.sync()

                #expect(store.settings == .fixture(sendsUsageData: false))
                #expect(store.state?.afterSequence == 9)
            }
        }

        @Suite("設定の記録の中身が読めないとき")
        struct UnreadableSettings {
            let store: SyncStoreMock
            let engine: SyncEngine

            init() {
                store = .ok(accountSettings: .fixture(sendsUsageData: false))
                engine = .fixture(
                    store: store,
                    transport: .ok(pullPages: [
                        """
                        {"changes":[
                          {"sequence":3,"kind":"account_settings","recordId":"x","record":{"sendsUsageData":true}}
                        ],"hasMore":false,"nextAfterSequence":3,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("落ちずに読み飛ばし、キャッシュの設定は変えず、通し番号は進めること")
            func skipsAndKeepsCache() async throws {
                _ = try await engine.sync()

                #expect(store.settings == .fixture(sendsUsageData: false))
                #expect(store.state?.afterSequence == 3)
            }
        }
    }

    @Suite("利用状況を送るかを読む")
    struct ReadUsageDataSetting {
        @Suite("初回の取得で設定の記録が届かなかったとき")
        struct NoSettingsPulled {
            let engine: SyncEngine

            init() {
                engine = .fixture(store: .ok(), transport: .ok())
            }

            @Test("既定のオンとみなし、PostHog を始めてよいと判定すること")
            func defaultsToOn() async throws {
                _ = try await engine.sync()

                let setting = try await engine.usageDataSetting()
                #expect(setting.sendsUsageData)
                #expect(setting.canStartPostHog)
            }
        }

        @Suite("初回の取得を終える前に、オフに切り替えたとき")
        struct ToggledOffBeforeInitialPull {
            let engine: SyncEngine

            init() {
                engine = .fixture(store: .ok(), transport: .ok())
            }

            @Test("オフとして読み、PostHog を始めないと判定すること")
            func staysStopped() async throws {
                try await engine.setSendsUsageData(false)

                let setting = try await engine.usageDataSetting()
                #expect(!setting.sendsUsageData)
                #expect(!setting.canStartPostHog)
            }
        }

        @Suite("初回の取得を終える前に、電波が無くて取りに行けないとき")
        struct BeforeInitialPull {
            let engine: SyncEngine

            init() {
                engine = .fixture(
                    store: .ok(),
                    transport: .error(URLError(.notConnectedToInternet))
                )
            }

            @Test("設定が無くても、PostHog を始めないと判定すること")
            func waitsForInitialPull() async throws {
                _ = try await engine.sync()

                let setting = try await engine.usageDataSetting()
                #expect(setting.sendsUsageData)
                #expect(!setting.canStartPostHog)
            }
        }

        @Suite("ほかの端末で切ったオフが、初回の取得で届いたとき")
        struct OffPulled {
            let engine: SyncEngine

            init() {
                let settingsId = AccountSettings.id(forAccountId: SyncEngine.fixtureAccountId)
                    .uuidString
                engine = .fixture(
                    store: .ok(),
                    transport: .ok(pullPages: [
                        """
                        {"changes":[{"sequence":1,"kind":"account_settings","recordId":"\(settingsId)",
                          "record":{"id":"\(settingsId)","sendsUsageData":false}}],
                         "hasMore":false,"nextAfterSequence":1,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("オフとして読み、PostHog を始めないと判定すること")
            func doesNotStart() async throws {
                _ = try await engine.sync()

                let setting = try await engine.usageDataSetting()
                #expect(!setting.sendsUsageData)
                #expect(!setting.canStartPostHog)
            }
        }
    }
}
