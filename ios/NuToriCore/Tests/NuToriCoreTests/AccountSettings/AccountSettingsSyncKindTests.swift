import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("アカウントの設定の同期の入口")
struct AccountSettingsSyncKindTests {
    @Suite("送り待ちから送る書き込みを作るとき")
    struct MakingWrite {
        let write: PendingAccountSettingsWrite

        init() {
            write = PendingAccountSettingsWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                write: .updateAccountSettings(.fixture(sendsUsageData: false)))
        }

        @Test("設定を直す書き込みにし、書き込みの ID を引き継ぐこと")
        func makesUpdateAccountSettings() throws {
            let sent = try AccountSettingsSyncKind().syncWrite(for: try write.entry())

            let settings = AccountSettings.fixture(sendsUsageData: false)
            #expect(
                sent
                    == .updateAccountSettings(
                        writeId: write.writeId,
                        settings: SyncedAccountSettings(
                            id: settings.id, sendsUsageData: settings.sendsUsageData)))
        }

        @Test("体重記録の送り待ちは、作れないこと")
        func rejectsOtherKind() throws {
            let weight = PendingWeightRecordWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                write: .sourceDeletedWeightRecord(recordId: UUID()))

            #expect(throws: PendingEntry.InvalidContentError.self) {
                try AccountSettingsSyncKind().syncWrite(for: try weight.entry())
            }
        }
    }

    @Suite("取りに行った変更を見分けるとき")
    struct Owning {
        let id = AccountSettings.fixture(sendsUsageData: true).id

        @Test("設定の変更だけを自分のものとすること")
        func ownsOnlySettings() {
            let kind = AccountSettingsSyncKind()

            #expect(kind.owns(.accountSettings(.init(id: id, sendsUsageData: true))))
            #expect(!kind.owns(.weightRecordDeletion(recordId: id)))
            #expect(!kind.owns(.unknown(kind: "note")))
        }

        @Test("複数届いたら、最後の設定を選び、無ければ nil にすること")
        func picksLast() {
            let changes: [SyncChange] = [
                .accountSettings(.init(id: id, sendsUsageData: true)),
                .unknown(kind: "note"),
                .accountSettings(.init(id: id, sendsUsageData: false)),
            ]

            #expect(
                AccountSettingsSyncKind.latestSettings(in: changes)
                    == AccountSettings(id: id, sendsUsageData: false))
            #expect(AccountSettingsSyncKind.latestSettings(in: []) == nil)
        }
    }

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let kind = AccountSettingsSyncKind()
        let cache = MemorySingleRecordCache<AccountSettings>()
        let id = AccountSettings.fixture(sendsUsageData: true).id

        @Test("届いた設定がキャッシュに入ること")
        func storesArrivedSettings() throws {
            try kind.apply([.accountSettings(.init(id: id, sendsUsageData: true))], to: cache)

            #expect(cache.read() == AccountSettings(id: id, sendsUsageData: true))
        }

        @Test("続けて届いたら、最後に届いた設定にすること")
        func keepsLatestSettings() throws {
            try kind.apply(
                [
                    .accountSettings(.init(id: id, sendsUsageData: true)),
                    .accountSettings(.init(id: id, sendsUsageData: false)),
                ], to: cache)

            #expect(cache.read() == AccountSettings(id: id, sendsUsageData: false))
        }

        @Test("設定の無い変更は、キャッシュの設定を変えないこと")
        func keepsSettingsWithoutChange() throws {
            try kind.apply([.accountSettings(.init(id: id, sendsUsageData: true))], to: cache)

            try kind.apply([.unknown(kind: "note")], to: cache)

            #expect(cache.read() == AccountSettings(id: id, sendsUsageData: true))
        }

        @Test("空にすると、設定がキャッシュから無くなること")
        func erases() throws {
            try kind.apply([.accountSettings(.init(id: id, sendsUsageData: true))], to: cache)

            try kind.erase(cache)

            #expect(cache.read() == nil)
        }
    }
}
