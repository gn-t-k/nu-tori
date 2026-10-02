import Foundation
import NuToriCore
import Testing

@Suite("締め出しの画面のボタンの行き先")
struct AppUpdateDestinationTests {
    @Test("App Store の版なら、nu-tori の App Store のページを開くこと")
    func appStorePage() {
        #expect(
            AppUpdateDestination.appStore(appId: 6_700_000_001).url
                == URL(string: "https://apps.apple.com/app/id6700000001"))
    }

    @Test("App Store がアプリに振る番号が分からないときは、App Store のアプリを開くこと")
    func appStoreWithoutAppId() {
        #expect(
            AppUpdateDestination.appStore(appId: nil).url
                == URL(string: "itms-apps://apps.apple.com"))
    }

    @Test("TestFlight の版なら、TestFlight のアプリを開くこと")
    func testFlightApp() {
        #expect(AppUpdateDestination.testFlight.url == URL(string: "itms-beta://"))
    }
}
