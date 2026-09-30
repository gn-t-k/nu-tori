import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("サーバーと端末の種類の名前")
struct RecordKindNameTests {
    @Suite("端末の登録簿を、サーバーの種類の名前の列挙と突き合わせるとき")
    struct MatchingServer {
        let registry: RecordKindRegistry<RecordCacheMock>
        let serverNames: Set<String>

        init() {
            registry = .ok()
            serverNames = ServerRecordKindNames.deviceNames
        }

        @Test("サーバーの列挙と登録簿の名前が、過不足なく揃っていること")
        func namesAreTheSame() {
            #expect(registry.mismatch(withServerNames: serverNames).isEmpty)
        }

        @Test("サーバーの名前を、端末の書き方（ハイフン）に寄せて突き合わせること")
        func convertsSnakeCaseToHyphen() {
            #expect(ServerRecordKindNames.names.contains("weight_record"))
            #expect(serverNames.contains("weight-record"))
        }
    }

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
                withServerNames: registry.names.union(["meal-photo"]))

            #expect(mismatch.onlyOnServer == ["meal-photo"])
            #expect(mismatch.onlyOnDevice.isEmpty)
            #expect(!mismatch.isEmpty)
        }

        // サーバーの列挙に無い名前を、端末が登録したとき
        @Test("端末にだけある名前を見つけること")
        func findsNameOnlyOnDevice() {
            let mismatch = registry.mismatch(withServerNames: ["weight-record"])

            #expect(mismatch.onlyOnDevice == ["account-settings"])
            #expect(mismatch.onlyOnServer.isEmpty)
            #expect(!mismatch.isEmpty)
        }
    }
}
