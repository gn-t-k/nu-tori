import Foundation
import NuToriAPI
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("まだ届いていない記録の見分け")
    struct Undelivered {
        static let day = CalendarDay(year: 2026, month: 9, day: 24)

        static func timeline(
            weightRecords: [WeightRecord] = [], meals: [MealCard] = [], pending: [PendingEntry]
        ) -> Timeline {
            Timeline(
                input: Timeline.Input(
                    weightRecords: weightRecords, rejectedLines: [], meals: meals, notices: [],
                    undelivered: UndeliveredRecords(pendingEntries: pending)),
                firstDay: day, today: day)
        }

        @Suite("体重記録")
        struct WeightRecords {
            let sent: WeightRecord
            let created: WeightRecord
            let timeline: Timeline

            init() throws {
                sent = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                created = try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
                timeline = Undelivered.timeline(
                    weightRecords: [sent, created],
                    pending: [
                        try PendingWeightRecordWrite(
                            enqueuedAt: created.instant, write: .createWeightRecord(created)
                        ).entry()
                    ])
            }

            @Test("作る書き込みが送り待ちに残っている体重記録を、まだ届いていないとすること")
            func createdIsUndelivered() {
                #expect(timeline.isUndelivered(.weightRecord(created)))
            }

            @Test("送り待ちに書き込みが無い体重記録を、届いたとすること")
            func sentIsDelivered() {
                #expect(!timeline.isUndelivered(.weightRecord(sent)))
            }
        }

        @Suite("食事のカード")
        struct Meals {
            let sent: MealCard
            let created: MealCard
            let timeline: Timeline

            init() throws {
                sent = try .fixture(status: .estimated)
                let meal = try Meal.fixture(
                    eatenAt: "2026-09-24T19:00:00+09:00", sentAt: "2026-09-24T19:01:00+09:00")
                created = MealCard(meal: meal, status: nil, recordedOnThisDevice: true)
                timeline = Undelivered.timeline(
                    meals: [sent, created],
                    pending: [
                        try PendingMealWrite(enqueuedAt: meal.sentAt, write: .create(meal)).entry()
                    ])
            }

            @Test("作る書き込みが送り待ちに残っている食事を、まだ届いていないとすること")
            func createdIsUndelivered() {
                #expect(timeline.isUndelivered(.meal(created)))
            }

            @Test("送り待ちに書き込みが無い食事を、届いたとすること")
            func sentIsDelivered() {
                #expect(!timeline.isUndelivered(.meal(sent)))
            }
        }

        @Suite("食事の画面で直したとき")
        struct EditedInMealScreen {
            static func card() throws -> (MealCard, Dish, Ingredient) {
                let meal = try Meal.fixture(
                    eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00")
                let dish = Dish.fixture(mealId: meal.id)
                let ingredient = Ingredient.fixture(dishId: dish.id)
                let card = MealCard(
                    meal: meal, status: .estimated, recordedOnThisDevice: true, dishes: [dish],
                    ingredients: [ingredient], dishEstimationStatuses: [:], unsentDishIds: [])
                return (card, dish, ingredient)
            }

            @Test("料理の量を直す書き込みが送り待ちに残っている食事を、まだ届いていないとすること")
            func dishCorrectedIsUndelivered() throws {
                let (card, dish, _) = try Self.card()
                let timeline = Undelivered.timeline(
                    meals: [card],
                    pending: [
                        try PendingDishWrite(
                            enqueuedAt: card.meal.sentAt,
                            write: .update(
                                DishCorrection(
                                    id: dish.id, name: dish.name,
                                    quantity: DishCorrection.Quantity(
                                        value: 2, proportionedIngredients: [])))
                        ).entry()
                    ])
                #expect(timeline.isUndelivered(.meal(card)))
            }

            @Test("料理を足す書き込みが送り待ちに残っている食事を、まだ届いていないとすること")
            func dishAddedIsUndelivered() throws {
                let (card, _, _) = try Self.card()
                let added = Dish.fixture(mealId: card.meal.id, name: "味噌汁", positionInMeal: 1)
                let withAdded = MealCard(
                    meal: card.meal, status: .estimated, recordedOnThisDevice: true,
                    dishes: card.contents.dishes.map(\.dish) + [added], ingredients: [],
                    dishEstimationStatuses: [:], unsentDishIds: [added.id])
                let timeline = Undelivered.timeline(
                    meals: [withAdded],
                    pending: [
                        try PendingDishWrite(
                            enqueuedAt: card.meal.sentAt,
                            write: .create(
                                NewDish(
                                    id: added.id, mealId: card.meal.id, name: added.name,
                                    positionInMeal: 1))
                        ).entry()
                    ])
                #expect(timeline.isUndelivered(.meal(withAdded)))
            }

            @Test("材料の量を直す書き込みが送り待ちに残っている食事を、まだ届いていないとすること")
            func ingredientCorrectedIsUndelivered() throws {
                let (card, _, ingredient) = try Self.card()
                let timeline = Undelivered.timeline(
                    meals: [card],
                    pending: [
                        try PendingIngredientWrite(
                            enqueuedAt: card.meal.sentAt,
                            write: .update(ingredientId: ingredient.id, quantity: 150)
                        ).entry()
                    ])
                #expect(timeline.isUndelivered(.meal(card)))
            }
        }

        @Suite("送った文章の吹き出し")
        struct SentTexts {
            static func timeline(sentText: SentText, pending: [SentTextWrite]) throws -> Timeline {
                Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: [],
                        undelivered: UndeliveredRecords(
                            pendingEntries: try pending.map {
                                try PendingSentTextWrite(enqueuedAt: sentText.sentAt, write: $0)
                                    .entry()
                            }),
                        conversation: Timeline.Conversation(sentTexts: [sentText], statuses: [:])),
                    firstDay: Undelivered.day, today: Undelivered.day)
            }

            static func isUndelivered(
                _ write: (SentText) -> SentTextWrite
            ) throws -> Bool {
                let sentText = try SentText.fixture(sentAt: "2026-09-24T12:11:00+09:00")
                let timeline = try Self.timeline(sentText: sentText, pending: [write(sentText)])
                return timeline.isUndelivered(
                    .sentText(SentTextBubble(sentText: sentText, replyLine: nil)))
            }

            @Test("作る書き込みが送り待ちに残っている文章を、まだ届いていないとすること")
            func createdIsUndelivered() throws {
                #expect(try Self.isUndelivered { .create($0) })
            }

            @Test("会話として送り直す書き込みが送り待ちに残っている文章を、まだ届いていないとすること")
            func resentAsConversationIsUndelivered() throws {
                #expect(try Self.isUndelivered { .resendAsConversation(sentTextId: $0.id) })
            }

            @Test("送り直す書き込みが送り待ちに残っている文章を、まだ届いていないとすること")
            func resentIsUndelivered() throws {
                #expect(try Self.isUndelivered { .resend(sentTextId: $0.id) })
            }

            @Test("送り待ちに書き込みが無い文章を、届いたとすること")
            func sentIsDelivered() throws {
                let sentText = try SentText.fixture(sentAt: "2026-09-24T12:11:00+09:00")
                let timeline = try Self.timeline(sentText: sentText, pending: [])
                #expect(
                    !timeline.isUndelivered(
                        .sentText(SentTextBubble(sentText: sentText, replyLine: .reading))))
            }
        }
    }
}
