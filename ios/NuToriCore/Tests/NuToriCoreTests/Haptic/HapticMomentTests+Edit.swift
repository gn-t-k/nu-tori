import Foundation
import NuToriCore
import Testing

extension HapticMomentTests {
    @Suite("編集を書いた結果のとき")
    struct Edit {
        let card: MealCard
        let dish: Dish
        let ingredient: Ingredient
        let record: WeightRecord
        let photo: MealPhotoOriginal
        let editedAt: Date
        let sentTextId: UUID
        let written = UserEdit.Outcome.written(recordCount: 1)

        init() throws {
            card = try MealCard.fixture(status: .estimated)
            dish = Dish.fixture(mealId: card.meal.id)
            ingredient = Ingredient.fixture(dishId: dish.id)
            record = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            photo = MealPhotoOriginal(
                data: Data([0xFF]), exif: PhotoExif(dateTimeOriginal: nil, offsetTimeOriginal: nil))
            editedAt = try Date("2026-09-24T13:00:00+09:00", strategy: .iso8601)
            sentTextId = UUID()
        }

        @Test("体重を記録して書けたら、記録が書けたときになること")
        func weightCreated() {
            let edit = UserEdit.saveWeight(
                .create(
                    kilograms: record.kilograms, instant: record.instant,
                    timeZone: record.timeZone))
            #expect(HapticMoment(edit, outcome: written) == .recordWritten)
        }

        @Test("体重を直して書けたら、記録が書けたときになること")
        func weightCorrected() {
            #expect(
                HapticMoment(.saveWeight(.correct(record)), outcome: written) == .recordWritten)
        }

        @Test("撮った写真で食事を記録して書けたら、記録が書けたときになること")
        func mealCaptured() {
            #expect(
                HapticMoment(.recordCapturedMeal(photo, sentAt: editedAt), outcome: written)
                    == .recordWritten)
        }

        @Test("選んだ写真で食事を記録して書けたら、記録が書けたときになること")
        func mealsPicked() {
            #expect(
                HapticMoment(.recordPickedMeals([photo], pickedAt: editedAt), outcome: written)
                    == .recordWritten)
        }

        @Test("食事の時刻を直して書けたら、記録が書けたときになること")
        func mealTimeCorrected() {
            #expect(
                HapticMoment(.correctMealTime(card, eatenAt: editedAt), outcome: written)
                    == .recordWritten)
        }

        @Test("食事を消して書けたら、記録が書けたときになること")
        func mealDeleted() {
            #expect(
                HapticMoment(.deleteMeal(card, deletedAt: editedAt), outcome: written)
                    == .recordWritten)
        }

        @Test("料理を足して書けたら、記録が書けたときになること")
        func dishAdded() {
            #expect(
                HapticMoment(.addDish(named: "味噌汁", to: card), outcome: written)
                    == .recordWritten)
        }

        @Test("料理の名前を直して書けたら、記録が書けたときになること")
        func dishRenamed() {
            #expect(
                HapticMoment(.renameDish(dish, to: "カツ丼"), outcome: written) == .recordWritten)
        }

        @Test("料理の量を直して書けたら、記録が書けたときになること")
        func dishQuantityCorrected() {
            #expect(
                HapticMoment(.correctDishQuantity(dish, to: 2), outcome: written)
                    == .recordWritten)
        }

        @Test("材料の量を直して書けたら、記録が書けたときになること")
        func ingredientQuantityCorrected() {
            #expect(
                HapticMoment(.correctIngredientQuantity(ingredient, to: 150), outcome: written)
                    == .recordWritten)
        }

        @Test("料理を消して書けたら、記録が書けたときになること")
        func dishDeleted() {
            #expect(HapticMoment(.deleteDish(dish), outcome: written) == .recordWritten)
        }

        @Test("今と同じ名前のように、書いたものが無い編集は、鳴らすときにならないこと")
        func unwritten() {
            #expect(HapticMoment(.renameDish(dish, to: dish.name), outcome: .unwritten) == nil)
        }

        @Test("返事を送り直す編集は、書けても、鳴らすときにならないこと")
        func replyResent() {
            #expect(
                HapticMoment(
                    .resendReply(sentTextId: sentTextId, reason: .halted), outcome: written)
                    == nil)
        }

        @Test("会話として送り直す編集は、書けても、鳴らすときにならないこと")
        func resentAsConversation() {
            #expect(
                HapticMoment(
                    .resendAsConversation(sentTextId: sentTextId, deletedMealCount: 1),
                    outcome: written) == nil)
        }
    }
}
