import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("サーバーと端末の種類の名前")
struct RecordKindNameTests {
    // 端末が登録を忘れたときは onlyOnServer に、サーバーの列挙に無い名前を端末が登録したときは onlyOnDevice に出る
    @Test("メモリの登録簿の名前が、サーバーの列挙と過不足なく揃っていること")
    func matchesServerKindNames() {
        let deviceNames = Set(RecordKindRegistry<RecordCacheMock>.ok().names.map(\.serverName))

        let onlyOnServer = ServerRecordKindNames.names.subtracting(deviceNames)
        let onlyOnDevice = deviceNames.subtracting(ServerRecordKindNames.names)

        #expect(onlyOnServer.isEmpty, "サーバーにだけ: \(onlyOnServer)")
        #expect(onlyOnDevice.isEmpty, "端末にだけ: \(onlyOnDevice)")
    }
}
