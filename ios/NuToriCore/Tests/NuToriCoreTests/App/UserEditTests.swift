import Foundation
import NuToriCore
import Testing

@Suite("画面からの編集")
struct UserEditTests {
    @Suite("書いたあとにヘルスケアへ書き出すもの")
    struct HealthExport {
        @Suite("体重の編集")
        struct Weight {
            let create: UserEdit
            let correct: UserEdit

            init() throws {
                let record = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                create = .saveWeight(
                    .create(kilograms: 72.4, instant: record.instant, timeZone: record.timeZone))
                correct = .saveWeight(.correct(record))
            }

            @Test("体重を記録すると、体重記録を書き出すこと")
            func exportsCreated() {
                #expect(create.healthExport == .weightRecord)
            }

            @Test("体重を直すと、体重記録を書き出すこと")
            func exportsCorrected() {
                #expect(correct.healthExport == .weightRecord)
            }
        }

        @Suite("消す編集")
        struct Deleting {
            let deleteMeal: UserEdit
            let deleteDish: UserEdit
            let resendAsConversation: UserEdit

            init() throws {
                let card = try MealCard.fixture(status: .estimated)
                deleteMeal = .deleteMeal(
                    card, deletedAt: try Date("2026-09-24T13:00:00+09:00", strategy: .iso8601))
                deleteDish = .deleteDish(Dish.fixture(mealId: card.meal.id))
                resendAsConversation = .resendAsConversation(
                    sentTextId: UUID(), deletedMealCount: 1)
            }

            @Test("食事を消すと、栄養を書き出し直すこと")
            func exportsAfterDeletingMeal() {
                #expect(deleteMeal.healthExport == .nutrition)
            }

            @Test("料理を消すと、栄養を書き出し直すこと")
            func exportsAfterDeletingDish() {
                #expect(deleteDish.healthExport == .nutrition)
            }

            @Test("会話として送り直すと、文章の食事が消えるので、栄養を書き出し直すこと")
            func exportsAfterResendingAsConversation() {
                #expect(resendAsConversation.healthExport == .nutrition)
            }
        }

        @Suite("食事を作る・直す編集")
        struct MealEditing {
            let recordCapturedMeal: UserEdit
            let recordPickedMeals: UserEdit
            let correctMealTime: UserEdit
            let addDish: UserEdit
            let renameDish: UserEdit
            let correctDishQuantity: UserEdit
            let correctIngredientQuantity: UserEdit

            init() throws {
                let photo = MealPhotoOriginal(
                    data: Data([0xFF]),
                    exif: PhotoExif(dateTimeOriginal: nil, offsetTimeOriginal: nil))
                let card = try MealCard.fixture(status: .estimated)
                let dish = Dish.fixture(mealId: card.meal.id)
                let editedAt = try Date("2026-09-24T13:00:00+09:00", strategy: .iso8601)
                recordCapturedMeal = .recordCapturedMeal(photo, sentAt: editedAt)
                recordPickedMeals = .recordPickedMeals([photo], pickedAt: editedAt)
                correctMealTime = .correctMealTime(card, eatenAt: editedAt)
                addDish = .addDish(named: "味噌汁", to: card)
                renameDish = .renameDish(dish, to: "カツ丼")
                correctDishQuantity = .correctDishQuantity(dish, to: 2)
                correctIngredientQuantity = .correctIngredientQuantity(
                    Ingredient.fixture(dishId: dish.id), to: 150)
            }

            @Test("撮った写真で食事を記録しても、書き出さないこと")
            func skipsCapturedMeal() {
                #expect(recordCapturedMeal.healthExport == .none)
            }

            @Test("選んだ写真で食事を記録しても、書き出さないこと")
            func skipsPickedMeals() {
                #expect(recordPickedMeals.healthExport == .none)
            }

            @Test("食事の時刻を直しても、書き出さないこと")
            func skipsMealTimeCorrection() {
                #expect(correctMealTime.healthExport == .none)
            }

            @Test("料理を足しても、書き出さないこと")
            func skipsAddedDish() {
                #expect(addDish.healthExport == .none)
            }

            @Test("料理の名前を直しても、書き出さないこと")
            func skipsRenamedDish() {
                #expect(renameDish.healthExport == .none)
            }

            @Test("料理の量を直しても、書き出さないこと")
            func skipsDishQuantityCorrection() {
                #expect(correctDishQuantity.healthExport == .none)
            }

            @Test("材料の量を直しても、書き出さないこと")
            func skipsIngredientQuantityCorrection() {
                #expect(correctIngredientQuantity.healthExport == .none)
            }
        }

        @Suite("文章の編集")
        struct TextEditing {
            let sendText: UserEdit
            let resendReply: UserEdit

            init() {
                sendText = .sendText(TextDraft(text: "こんにちは"))
                resendReply = .resendReply(sentTextId: UUID(), reason: .halted)
            }

            @Test("文章を送っても、書き出さないこと")
            func skipsSentText() {
                #expect(sendText.healthExport == .none)
            }

            @Test("返事を作り直させても、書き出さないこと")
            func skipsReplyResend() {
                #expect(resendReply.healthExport == .none)
            }
        }
    }
}
