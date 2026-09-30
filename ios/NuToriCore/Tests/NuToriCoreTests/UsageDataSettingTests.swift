import NuToriCore
import Testing

@Suite("利用状況を送るか")
struct UsageDataSettingTests {
    @Suite("アカウントの設定がまだ無いとき")
    struct NoAccountSettings {
        @Test("サインインの同意で取っている既定のオンになること")
        func defaultsToOn() {
            #expect(UsageDataSetting.sendsUsageData(nil))
        }
    }

    @Suite("アカウントの設定でオフにしてあるとき")
    struct TurnedOff {
        @Test("オフになること")
        func isOff() {
            #expect(!UsageDataSetting.sendsUsageData(.fixture(sendsUsageData: false)))
        }
    }
}
