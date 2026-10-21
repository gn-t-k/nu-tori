import Foundation
import NuToriCore
import Testing

@Suite("タイムラインの元をキャッシュの記録から組む")
struct TimelineRecordsTests {
    @Suite("食事のカード")
    struct MealCards {
        @Suite("食事と、その料理・材料・状態がそろっているとき")
        struct Complete {
            let meal: Meal
            let dish: Dish
            let ingredient: Ingredient
            let records: TimelineRecords

            init() throws {
                meal = try .fixture(
                    eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
                dish = .fixture(mealId: meal.id)
                ingredient = .fixture(dishId: dish.id)
                records = TimelineRecords(
                    meals: [meal],
                    mealEstimationStatuses: [.init(mealId: meal.id, status: .estimated)],
                    dishes: [dish],
                    dishEstimationStatuses: [.init(dishId: dish.id, status: .estimating)],
                    ingredients: [ingredient], sentTexts: [], sentTextStatuses: [], replies: [])
            }

            @Test("食事ごとに、状態と料理と材料を入れたカードにすること")
            func joinsIntoCard() {
                #expect(
                    records.mealCards(recordedOnThisDevice: [meal.id], unsentDishIds: [dish.id])
                        == [
                            MealCard(
                                meal: meal, status: .estimated, recordedOnThisDevice: true,
                                dishes: [dish], ingredients: [ingredient],
                                dishEstimationStatuses: [dish.id: .estimating],
                                unsentDishIds: [dish.id])
                        ])
            }

            @Test("この端末で記録していない食事は、ほかの端末の食事のカードにすること")
            func marksOtherDevice() {
                #expect(
                    records.mealCards(recordedOnThisDevice: [], unsentDishIds: []).map(
                        \.recordedOnThisDevice) == [false])
            }
        }

        @Suite("料理と材料と推定の状態が、食事より先に届いたとき")
        struct ChildrenBeforeMeal {
            let records: TimelineRecords

            init() {
                let mealId = UUID()
                let dish = Dish.fixture(mealId: mealId)
                records = TimelineRecords(
                    meals: [],
                    mealEstimationStatuses: [.init(mealId: mealId, status: .estimated)],
                    dishes: [dish],
                    dishEstimationStatuses: [.init(dishId: dish.id, status: .estimated)],
                    ingredients: [.fixture(dishId: dish.id)], sentTexts: [],
                    sentTextStatuses: [], replies: [])
            }

            @Test("食事が届くまでカードを作らないこと")
            func makesNoCard() {
                #expect(records.mealCards(recordedOnThisDevice: [], unsentDishIds: []).isEmpty)
            }
        }

        @Suite("材料が料理より先に届いたとき")
        struct IngredientBeforeDish {
            let records: TimelineRecords

            init() throws {
                let meal = try Meal.fixture(
                    eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
                records = TimelineRecords(
                    meals: [meal], mealEstimationStatuses: [], dishes: [],
                    dishEstimationStatuses: [], ingredients: [.fixture(dishId: UUID())],
                    sentTexts: [], sentTextStatuses: [], replies: [])
            }

            @Test("料理が届くまで材料を入れないこと")
            func leavesOutIngredient() {
                #expect(
                    records.mealCards(recordedOnThisDevice: [], unsentDishIds: []).map(
                        \.contents.dishes.isEmpty) == [true])
            }
        }

        @Suite("ほかの食事の料理があるとき")
        struct OtherMealsDish {
            let lunch: Meal
            let lunchDish: Dish
            let records: TimelineRecords

            init() throws {
                lunch = try .fixture(
                    eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
                let dinner = try Meal.fixture(
                    eatenAt: "2026-09-24T19:10:00+09:00", sentAt: "2026-09-24T19:11:00+09:00")
                lunchDish = .fixture(mealId: lunch.id, name: "親子丼")
                records = TimelineRecords(
                    meals: [lunch, dinner], mealEstimationStatuses: [],
                    dishes: [lunchDish, .fixture(mealId: dinner.id, name: "焼き魚")],
                    dishEstimationStatuses: [], ingredients: [], sentTexts: [],
                    sentTextStatuses: [], replies: [])
            }

            @Test("食事の順に、それぞれの食事の料理だけを入れること")
            func keepsDishesToTheirMeal() {
                let cards = records.mealCards(recordedOnThisDevice: [], unsentDishIds: [])
                #expect(cards.map(\.meal.id).first == lunch.id)
                #expect(cards.first?.contents.dishes.map(\.dish.id) == [lunchDish.id])
            }
        }

        @Suite("同じ食事の推定の状態が2つあるとき")
        struct TwoStatusesForOneMeal {
            let records: TimelineRecords

            init() throws {
                let meal = try Meal.fixture(
                    eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
                records = TimelineRecords(
                    meals: [meal],
                    mealEstimationStatuses: [
                        .init(mealId: meal.id, status: .estimating),
                        .init(mealId: meal.id, status: .estimated),
                    ],
                    dishes: [], dishEstimationStatuses: [], ingredients: [], sentTexts: [],
                    sentTextStatuses: [], replies: [])
            }

            @Test("あとの状態を取ること")
            func takesLast() {
                #expect(
                    records.mealCards(recordedOnThisDevice: [], unsentDishIds: []).map(\.status)
                        == [.estimated])
            }
        }
    }

    @Suite("会話")
    struct Conversation {
        @Suite("同じ送った文章の状態が2つあるとき")
        struct TwoStatusesForOneSentText {
            let sentText: SentText
            let records: TimelineRecords

            init() throws {
                sentText = try .fixture(sentAt: "2026-09-24T12:11:00+09:00")
                records = TimelineRecords(
                    meals: [], mealEstimationStatuses: [], dishes: [],
                    dishEstimationStatuses: [], ingredients: [], sentTexts: [sentText],
                    sentTextStatuses: [
                        .init(
                            sentTextId: sentText.id,
                            status: SentTextStatus(classification: .pending, reply: .notRequested)
                        ),
                        .init(
                            sentTextId: sentText.id,
                            status: SentTextStatus(classification: .conversation, reply: .replied)
                        ),
                    ],
                    replies: [])
            }

            @Test("あとの状態を取ること")
            func takesLast() {
                #expect(
                    records.conversation(streams: [:]).statuses
                        == [
                            sentText.id: SentTextStatus(
                                classification: .conversation, reply: .replied)
                        ])
            }
        }

        @Suite("状態と返事が、送った文章より先に届いたとき")
        struct ArrivedBeforeSentText {
            let sentTextId: UUID
            let reply: AiUtterance
            let records: TimelineRecords

            init() {
                sentTextId = UUID()
                reply = AiUtterance(
                    id: UUID(), body: "野菜の多い定食はどうでしょう。", sentTextId: sentTextId, mealIds: [])
                records = TimelineRecords(
                    meals: [], mealEstimationStatuses: [], dishes: [],
                    dishEstimationStatuses: [], ingredients: [], sentTexts: [],
                    sentTextStatuses: [
                        .init(
                            sentTextId: sentTextId,
                            status: SentTextStatus(classification: .conversation, reply: .replied)
                        )
                    ],
                    replies: [reply])
            }

            @Test("会話の元に持ち、送った文章が届くのを待つこと")
            func keepsForLater() {
                let conversation = records.conversation(streams: [:])
                #expect(conversation.sentTexts.isEmpty)
                #expect(conversation.statuses.keys.contains(sentTextId))
                #expect(conversation.replies == [reply])
            }
        }
    }
}
