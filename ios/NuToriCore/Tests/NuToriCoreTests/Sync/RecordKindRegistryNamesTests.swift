import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("記録の種類の名前")
struct RecordKindRegistryNamesTests {
    @Test("メモリの登録簿の種類が、サーバーの種類の名前の列挙と過不足なく揃っていること")
    func matchesServerKindNames() {
        let deviceNames = Set(RecordKindRegistry<RecordCacheMock>.ok().names.map(\.serverName))

        #expect(deviceNames == ServerRecordKindNames.names)
        #expect(
            deviceNames == [
                "account_settings", "dish", "ingredient", "meal", "meal_estimation_status",
                "weight_record",
            ])
    }

    @Test("端末の種類の名前は、すべてに対応するサーバーの名前があり、名前の順に並ぶこと")
    func everyKindHasServerName() {
        #expect(Set(RecordKindName.allCases.map(\.serverName)) == ServerRecordKindNames.names)
        #expect(
            RecordKindRegistry<RecordCacheMock>.ok().names.sorted()
                == RecordKindName.allCases.sorted())
    }
}
