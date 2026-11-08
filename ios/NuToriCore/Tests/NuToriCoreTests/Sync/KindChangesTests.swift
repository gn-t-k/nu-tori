import Foundation
import NuToriAPI
import NuToriCore
import Testing

private let meal = SyncChange.mealDeletion(mealId: UUID())
private let otherMeal = SyncChange.mealDeletion(mealId: UUID())
private let status = SyncChange.mealEstimationStatusDeletion(mealId: UUID())

@Suite("種類に当てる変更")
struct KindChangesTests {
    @Suite("並んだ変更をまとめるとき")
    struct Grouping {
        @Test("続けて並ぶ同じ種類だけを1つにまとめ、並びを変えないこと")
        func groupsConsecutiveRuns() {
            let groups = KindChanges.grouping([meal, otherMeal, status, meal])

            #expect(groups.map(\.kind) == [.meal, .mealEstimationStatus, .meal])
            #expect(groups.map(\.changes) == [[meal, otherMeal], [status], [meal]])
        }

        @Test("知らない種類の変更は読み飛ばし、空の種類を作らないこと")
        func skipsUnknownChanges() {
            #expect(KindChanges.grouping([.unknown(kind: "note")]).isEmpty)
            #expect(KindChanges.grouping([]).isEmpty)
        }
    }

    @Suite("その種類の変更を取り出すとき")
    struct Owned {
        @Test("その種類の変更だけを、並びを変えずに取り出すこと")
        func keepsOnlyThatKind() {
            let owned = KindChanges.owned(
                by: .meal, in: [meal, status, .unknown(kind: "meal"), otherMeal])

            #expect(owned.kind == .meal)
            #expect(owned.changes == [meal, otherMeal])
        }
    }
}
