import NuToriCore
import NuToriTestSupport
import Testing

@Suite("サーバーと端末の種類の名前")
struct RecordKindNameTests {
    @Suite("片方にだけある名前があるとき")
    struct Mismatching {
        let registry: RecordKindRegistry<RecordCacheMock>

        init() {
            registry = .ok()
        }

        // 端末が登録を忘れたとき
        @Test("サーバーにだけある名前を見つけること")
        func findsNameOnlyOnServer() {
            let mismatch = registry.mismatch(
                withServerNames: Set(registry.names.map(\.serverName)).union(["meal_photo"]))

            #expect(mismatch.onlyOnServer == ["meal_photo"])
            #expect(mismatch.onlyOnDevice.isEmpty)
            #expect(!mismatch.isEmpty)
        }

        // サーバーの列挙に無い名前を、端末が登録したとき
        @Test("端末にだけある名前を見つけること")
        func findsNameOnlyOnDevice() {
            let mismatch = registry.mismatch(withServerNames: ["weight_record"])

            #expect(mismatch.onlyOnDevice == ["account_settings"])
            #expect(mismatch.onlyOnServer.isEmpty)
            #expect(!mismatch.isEmpty)
        }
    }
}
