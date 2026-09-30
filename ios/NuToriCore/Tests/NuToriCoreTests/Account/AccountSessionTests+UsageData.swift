import NuToriCore
import Testing

extension AccountSessionTests {
    @Suite("利用状況を送るかを切り替えるとき")
    struct ChangingUsageData {
        @Suite("オフにするとき")
        struct TurningOff {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn()
                session = device.session()
            }

            @Test("オフにした1件を送って PostHog を止めてから、設定を保存すること")
            func turnsOffThenSaves() async throws {
                try await session.changeSendsUsageData(to: false)

                let events = device.log.events
                let capture = try #require(events.firstIndex(of: "analytics.capture"))
                let reset = try #require(events.firstIndex(of: "analytics.reset"))
                #expect(capture < reset)
                #expect(device.analytics.captured == [.usageDataTurnedOff])
                #expect(device.analytics.resetCount == 1)
                #expect(device.analytics.identifiedAccountIds.isEmpty)
                let settings = try #require(device.syncStore.settings)
                #expect(!settings.sendsUsageData)
                #expect(
                    settings.id
                        == AccountSettings.id(
                            forAccountId: AccountDevice.previousAccount.accountId))
                #expect(
                    device.syncStore.pending.last?.operation == .updateAccountSettings(settings))
            }
        }

        @Suite("オンに戻すとき")
        struct TurningOn {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(
                    accountSettings: AccountSettings(
                        id: AccountSettings.id(
                            forAccountId: AccountDevice.previousAccount.accountId),
                        sendsUsageData: false
                    )
                )
                session = device.session()
            }

            @Test("設定を保存してから PostHog を始めること")
            func savesThenStarts() async throws {
                try await session.changeSendsUsageData(to: true)

                #expect(device.analytics.captured.isEmpty)
                #expect(device.analytics.resetCount == 0)
                #expect(
                    device.analytics.identifiedAccountIds == [
                        AccountDevice.previousAccount.accountId
                    ])
                #expect(
                    device.errorReporting.identifiedAccountIds == [
                        AccountDevice.previousAccount.accountId
                    ])
                #expect(device.syncStore.settings?.sendsUsageData == true)
            }
        }
    }
}
