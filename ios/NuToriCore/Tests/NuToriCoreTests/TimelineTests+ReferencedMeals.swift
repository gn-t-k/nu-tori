import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("返事が指し示す食事")
    struct ReferencedMeals {
        let lunch: MealCard
        let dinner: MealCard
        let deletedMealId: UUID
        let timeline: Timeline

        init() throws {
            lunch = MealCard(
                meal: try .fixture(
                    eatenAt: "2026-09-24T12:00:00+09:00", sentAt: "2026-09-24T12:01:00+09:00"),
                status: .estimated, recordedOnThisDevice: true)
            dinner = MealCard(
                meal: try .fixture(
                    eatenAt: "2026-09-23T19:00:00+09:00", sentAt: "2026-09-23T19:01:00+09:00"),
                status: .estimated, recordedOnThisDevice: true)
            deletedMealId = UUID()
            let sentText = try SentText.fixture(
                "昼と昨日の夜の記録を直して", sentAt: "2026-09-24T13:00:00+09:00")
            timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [], rejectedLines: [], meals: [lunch, dinner], notices: [],
                    undelivered: .none,
                    conversation: Timeline.Conversation(
                        sentTexts: [sentText],
                        statuses: [
                            sentText.id: SentTextStatus(
                                classification: .conversation, reply: .replied)
                        ],
                        replies: [
                            AiUtterance(
                                id: UUID(), body: "この食事のことですね。", sentTextId: sentText.id,
                                mealIds: [dinner.meal.id, deletedMealId, lunch.meal.id])
                        ], streams: [:])),
                // 使い始めた日より前の食事も指せる
                firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                today: CalendarDay(year: 2026, month: 9, day: 24))
        }

        @Test("返った順に食事の行を並べ、キャッシュに無い食事を削除した食事にすること")
        func listsMealsInOrder() {
            let replies = timeline.days.flatMap(\.items).compactMap { item in
                if case .reply(let reply) = item { reply } else { nil }
            }
            #expect(
                replies.map(\.referencedMeals) == [
                    [.meal(dinner), .deleted(mealId: deletedMealId), .meal(lunch)]
                ])
        }
    }
}
