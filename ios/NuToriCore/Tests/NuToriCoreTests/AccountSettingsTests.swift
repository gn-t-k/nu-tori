import Foundation
import NuToriCore
import Testing

@Suite("アカウントの設定")
struct AccountSettingsTests {
    @Suite("アカウント ID から設定の ID を出すとき")
    struct DeriveId {
        let accountId: String
        let otherAccountId: String
        let expectedId: UUID

        init() throws {
            accountId = "5b1f2c1e-3a58-4d5b-9c0e-8f7a6d5c4b3a"
            otherAccountId = "0d7c5a4e-1b2f-4e3d-8a9b-7c6d5e4f3a2b"
            expectedId = try #require(UUID(uuidString: "828E2DA5-CC37-5BB2-9140-C78F8314B1DE"))
        }

        @Test("固定の名前空間の UUID v5 になり、どの端末でも同じ値になること")
        func isStableAcrossDevices() {
            #expect(AccountSettings.id(forAccountId: accountId) == expectedId)
        }

        @Test("アカウントが違えば、違う ID になること")
        func differsPerAccount() {
            #expect(
                AccountSettings.id(forAccountId: accountId)
                    != AccountSettings.id(forAccountId: otherAccountId))
        }
    }
}
