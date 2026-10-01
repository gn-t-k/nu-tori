import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("アプリの登録簿")
struct AppRecordKindsTests {
    @Test("サーバーの種類の名前の列挙と、過不足なく揃っていること")
    func matchesServerKindNames() {
        let deviceNames = Set(AppRecordKinds.registry.names.map(\.serverName))

        let onlyOnServer = ServerRecordKindNames.names.subtracting(deviceNames)
        let onlyOnDevice = deviceNames.subtracting(ServerRecordKindNames.names)

        #expect(onlyOnServer.isEmpty, "サーバーにだけ: \(onlyOnServer)")
        #expect(onlyOnDevice.isEmpty, "端末にだけ: \(onlyOnDevice)")
    }
}
