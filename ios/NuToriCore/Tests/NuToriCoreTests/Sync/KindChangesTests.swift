import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("種類に当てる変更")
struct KindChangesTests {
    @Suite("同じ種類が続けて並ぶ変更をまとめるとき")
    struct Grouping {
        let meal: SyncChange
        let otherMeal: SyncChange
        let status: SyncChange

        init() {
            meal = .mealDeletion(mealId: UUID())
            otherMeal = .mealDeletion(mealId: UUID())
            status = .mealEstimationStatusDeletion(mealId: UUID())
        }

        @Test("続けて並ぶ同じ種類だけを1つにまとめ、並びを変えないこと")
        func groupsConsecutiveRuns() {
            let groups = KindChanges.grouping([meal, otherMeal, status, meal])

            #expect(groups.map(\.kind) == [.meal, .mealEstimationStatus, .meal])
            #expect(groups.map(\.changes) == [[meal, otherMeal], [status], [meal]])
        }
    }

    @Suite("知らない種類の変更だけをまとめるとき")
    struct GroupingUnknown {
        @Test("読み飛ばし、空の種類を作らないこと")
        func skipsUnknownChanges() {
            #expect(KindChanges.grouping([.unknown(kind: "note")]).isEmpty)
        }
    }

    @Suite("その種類の変更を取り出すとき")
    struct Owned {
        let meal: SyncChange
        let otherMeal: SyncChange
        let status: SyncChange

        init() {
            meal = .mealDeletion(mealId: UUID())
            otherMeal = .mealDeletion(mealId: UUID())
            status = .mealEstimationStatusDeletion(mealId: UUID())
        }

        @Test("その種類の変更だけを、並びを変えずに取り出すこと")
        func keepsOnlyThatKind() {
            let owned = KindChanges.owned(
                by: .meal, in: [meal, status, .unknown(kind: "meal"), otherMeal])

            #expect(owned.kind == .meal)
            #expect(owned.changes == [meal, otherMeal])
        }
    }
}
