import Foundation
import NuToriCore
import Testing

extension HapticMomentTests {
    @Suite("体重・食事・料理の画面から編集を送ったとき")
    struct Editing {
        let card: MealCard
        let dish: Dish
        let editedAt: Date

        init() throws {
            card = try MealCard.fixture(status: .estimated)
            dish = Dish.fixture(mealId: card.meal.id)
            editedAt = try Date("2026-09-24T13:00:00+09:00", strategy: .iso8601)
        }

        @Test("体重を直したら、記録を直したときになること")
        func weightCorrected() throws {
            let record = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            #expect(HapticMoment(editing: .saveWeight(.correct(record))) == .recordCorrected)
        }

        @Test("食事の時刻を直したら、記録を直したときになること")
        func mealTimeCorrected() {
            #expect(
                HapticMoment(editing: .correctMealTime(card, eatenAt: editedAt))
                    == .recordCorrected)
        }

        @Test("料理の名前を直したら、記録を直したときになること")
        func dishRenamed() {
            #expect(HapticMoment(editing: .renameDish(dish, to: "カツ丼")) == .recordCorrected)
        }

        @Test("料理の量を直したら、記録を直したときになること")
        func dishQuantityCorrected() {
            #expect(HapticMoment(editing: .correctDishQuantity(dish, to: 2)) == .recordCorrected)
        }

        @Test("材料の量を直したら、記録を直したときになること")
        func ingredientQuantityCorrected() {
            let edit = UserEdit.correctIngredientQuantity(
                Ingredient.fixture(dishId: dish.id), to: 150)
            #expect(HapticMoment(editing: edit) == .recordCorrected)
        }

        @Test("料理を足したら、料理を足したときになること")
        func dishAdded() {
            #expect(HapticMoment(editing: .addDish(named: "味噌汁", to: card)) == .dishAdded)
        }

        @Test("料理を消したら、料理を削除したときになること")
        func dishDeleted() {
            #expect(HapticMoment(editing: .deleteDish(dish)) == .dishDeleted)
        }

        @Test("食事を消したら、食事を削除したときになること")
        func mealDeleted() {
            #expect(
                HapticMoment(editing: .deleteMeal(card, deletedAt: editedAt)) == .mealDeleted)
        }

        @Test("体重を記録する編集は、押した場所ごとにときが違うので、ここでは決めないこと")
        func weightCreated() {
            let edit = UserEdit.saveWeight(
                .create(kilograms: 72.4, instant: editedAt, timeZone: .gmt))
            #expect(HapticMoment(editing: edit) == nil)
        }

        @Test("返事を送り直す編集は、記録を直す編集でないので、ここでは決めないこと")
        func replyResent() {
            let edit = UserEdit.resendReply(sentTextId: UUID(), reason: .halted)
            #expect(HapticMoment(editing: edit) == nil)
        }
    }
}
