import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("変更の種類の名前")
struct SyncChangeKindNameTests {
    @Suite("端末が知っている種類の変更のとき")
    struct Known {
        let id: UUID

        init() {
            id = UUID()
        }

        @Test("今の値も削除の印も、その種類の名前になること")
        func namesValueAndDeletion() {
            #expect(SyncChange.weightRecordDeletion(recordId: id).kindName == .weightRecord)
            #expect(SyncChange.dishDeletion(dishId: id).kindName == .dish)
            #expect(SyncChange.ingredientDeletion(ingredientId: id).kindName == .ingredient)
            #expect(
                SyncChange.accountSettings(SyncedAccountSettings(id: id, sendsUsageData: true))
                    .kindName == .accountSettings)
        }
    }

    @Suite("知らない種類の変更のとき")
    struct Unknown {
        @Test("名前が無いこと")
        func hasNoName() {
            #expect(SyncChange.unknown(kind: "note").kindName == nil)
        }
    }
}
