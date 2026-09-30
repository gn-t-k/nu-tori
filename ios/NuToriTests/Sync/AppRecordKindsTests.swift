import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("アプリの登録簿")
struct AppRecordKindsTests {
    @Test("サーバーの種類の名前の列挙と、過不足なく揃っていること")
    func matchesServerKindNames() {
        let mismatch = AppRecordKinds.registry.mismatch(
            withServerNames: ServerRecordKindNames.names)

        #expect(
            mismatch.isEmpty, "サーバーにだけ: \(mismatch.onlyOnServer)、端末にだけ: \(mismatch.onlyOnDevice)")
    }
}
