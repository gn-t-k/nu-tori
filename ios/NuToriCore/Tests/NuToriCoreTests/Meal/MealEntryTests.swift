import Foundation
import NuToriCore
import Testing

@Suite("食事の入口が写真の入口か")
struct MealEntryTests {
    @Suite("撮った食事のとき")
    struct Captured {
        let entry: Meal.Entry

        init() {
            entry = .captured
        }

        @Test("写真の入口と判定すること")
        func isPhoto() {
            #expect(entry.isPhoto)
        }
    }

    @Suite("撮っておいた写真を選んだ食事のとき")
    struct Picked {
        let entry: Meal.Entry

        init() {
            entry = .picked
        }

        @Test("写真の入口と判定すること")
        func isPhoto() {
            #expect(entry.isPhoto)
        }
    }

    @Suite("文章の食事のとき")
    struct Written {
        let entry: Meal.Entry

        init() {
            entry = .written(sentTextId: UUID())
        }

        @Test("写真の入口と判定しないこと")
        func isNotPhoto() {
            #expect(!entry.isPhoto)
        }
    }
}
