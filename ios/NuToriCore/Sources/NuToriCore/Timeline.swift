import Foundation

public struct Timeline: Sendable {
    /// タイムラインに並べる日で、日のまとめで送れる日でもある
    public let dayRange: ClosedRange<CalendarDay>

    public init(input: Input, firstDay: CalendarDay, today: CalendarDay) {
        let weightRecordsByDay = Dictionary(
            grouping: input.weightRecords.filter { $0.day >= firstDay }, by: \.day)
        let mealsByDay = Dictionary(
            grouping: input.meals.filter { $0.meal.cardDay >= firstDay }, by: \.meal.cardDay)
        // 1日の丸と日のまとめには、カードを置く日でなく、食事の日（撮った時刻と食事の時差から出した日）に入れる。
        // 食事の日が使い始めた日より前の食事は、カードは並べても、丸にも日のまとめにも入れない
        let mealsByEatenDay = Dictionary(
            grouping: input.meals.filter { $0.meal.day >= firstDay }, by: \.meal.day)
        let noticesByDay = Dictionary(
            grouping: input.notices.filter { $0.targetDay >= firstDay }, by: \.targetDay)
        let rejectedWeightLines = input.rejectedLines.compactMap(\.weightLine)
        let rejectedMealLines = input.rejectedLines.compactMap(\.mealLine)
        let lastDay = ([today] + weightRecordsByDay.keys + mealsByDay.keys + noticesByDay.keys)
            .max()!
        let range = firstDay...max(firstDay, lastDay)
        dayRange = range
        days = range.map { day in
            Day(
                day: day,
                items: Self.items(
                    records: weightRecordsByDay[day] ?? [],
                    rejectedLines: rejectedWeightLines.filter { $0.record.day == day },
                    meals: mealsByDay[day] ?? [],
                    rejectedMealLines: rejectedMealLines.filter { $0.meal.cardDay == day },
                    notices: (noticesByDay[day] ?? []).map { NoticeCard(notice: $0, today: today) }
                ),
                food: DayFood(meals: mealsByEatenDay[day] ?? [])
            )
        }
    }

    /// 古い日から新しい日へ
    public let days: [Day]

    /// 今日の答えていない知らせ。画面の上へ流れて見えないときに、帯の下の1行で示す。
    /// 答えていない形のカードは、対象の日付が今日の知らせにだけあり、今日の日に並ぶ
    public var noticeAwaitingAnswer: NoticeCard? {
        days.lazy.flatMap(\.items)
            .compactMap { item -> NoticeCard? in
                if case .notice(let card) = item, card.form == .awaitingAnswer { card } else { nil }
            }
            .first
    }

    /// タイムラインに並べる元になるもの。種類が増えたら欄を足す
    public struct Input: Sendable {
        public let weightRecords: [WeightRecord]
        /// サーバーが受け付けなかった体重記録と食事の行
        public let rejectedLines: [RejectedLine]
        public let meals: [MealCard]
        /// 答えた知らせも含む
        public let notices: [Notice]

        public init(
            weightRecords: [WeightRecord],
            rejectedLines: [RejectedLine],
            meals: [MealCard],
            notices: [Notice]
        ) {
            self.weightRecords = weightRecords
            self.rejectedLines = rejectedLines
            self.meals = meals
            self.notices = notices
        }
    }

    public struct Day: Hashable, Sendable {
        public let day: CalendarDay
        /// 体重記録は時刻、食事は送った時刻、知らせは出した時刻の順。受け付けなかった行は、その位置に入る
        public let items: [Item]
        /// この日の食べた量。この日に食べた（食事の日がこの日の）食事から出す。カードを置く日の食事とは限らない
        public let food: DayFood

        public init(day: CalendarDay, items: [Item], food: DayFood) {
            self.day = day
            self.items = items
            self.food = food
        }

        public var representativeWeight: RepresentativeWeight? {
            RepresentativeWeight(
                sameDayRecords: items.compactMap {
                    if case .weightRecord(let record) = $0 { record } else { nil }
                })
        }

        /// 1日の丸の帯に出す、この日の丸
        public var ring: DayRing {
            DayRing(
                hasWeightRecord: items.contains {
                    if case .weightRecord = $0 { true } else { false }
                },
                food: food)
        }
    }

    public enum Item: Hashable, Sendable, Identifiable {
        case weightRecord(WeightRecord)
        case rejectedWeightLine(RejectedWeightLine)
        case meal(MealCard)
        case rejectedMealLine(RejectedMealLine)
        case notice(NoticeCard)

        public var id: String {
            switch self {
            case .weightRecord(let record): "record-\(record.id.uuidString)"
            case .rejectedWeightLine(let line): "rejection-\(line.record.id.uuidString)"
            case .meal(let card): "meal-\(card.meal.id.uuidString)"
            case .rejectedMealLine(let line): "meal-rejection-\(line.meal.id.uuidString)"
            case .notice(let card): "notice-\(card.notice.id.uuidString)"
            }
        }
    }

    /// 体重記録と食事と知らせを時刻の順に並べ、受け付けなかった体重の行をその位置に入れる
    private static func items(
        records: [WeightRecord],
        rejectedLines: [RejectedWeightLine],
        meals: [MealCard],
        rejectedMealLines: [RejectedMealLine],
        notices: [NoticeCard]
    ) -> [Item] {
        var placed =
            (records.map { Placed(record: $0) } + meals.map { Placed(card: $0) }
            + rejectedMealLines.map { Placed(line: $0) } + notices.map { Placed(notice: $0) })
            .sorted()
        for line in rejectedLines.sorted(by: { $0.record.instant < $1.record.instant }) {
            let lineItem = Placed(
                instant: line.record.instant, eatenAt: nil, item: .rejectedWeightLine(line))
            switch line.placement {
            case .belowRecord:
                if let index = placed.firstIndex(where: { placedItem in
                    guard case .weightRecord(let record) = placedItem.item else { return false }
                    return record.id == line.record.id
                }) {
                    placed.insert(lineItem, at: index + 1)
                } else {
                    placed.append(lineItem)
                }
            case .insteadOfRecord:
                let index =
                    placed.firstIndex { $0.instant > line.record.instant } ?? placed.endIndex
                placed.insert(lineItem, at: index)
            }
        }
        return placed.map(\.item)
    }

    /// 並べる位置。体重記録は時刻、食事とその行は送った時刻で並べ、同じ送った時刻の食事は撮った時刻の順にする
    private struct Placed: Comparable {
        let instant: Date
        /// 食事だけが持つ。同じ時刻なら、持たない体重記録を先にする
        let eatenAt: Date?
        let item: Item

        init(instant: Date, eatenAt: Date?, item: Item) {
            self.instant = instant
            self.eatenAt = eatenAt
            self.item = item
        }

        init(record: WeightRecord) {
            self.init(instant: record.instant, eatenAt: nil, item: .weightRecord(record))
        }

        init(card: MealCard) {
            self.init(instant: card.meal.sentAt, eatenAt: card.meal.eatenAt, item: .meal(card))
        }

        init(line: RejectedMealLine) {
            self.init(
                instant: line.meal.sentAt, eatenAt: line.meal.eatenAt,
                item: .rejectedMealLine(line))
        }

        init(notice: NoticeCard) {
            self.init(instant: notice.notice.issuedAt, eatenAt: nil, item: .notice(notice))
        }

        static func < (lhs: Placed, rhs: Placed) -> Bool {
            (lhs.instant, lhs.eatenAt ?? .distantPast, lhs.item.id)
                < (rhs.instant, rhs.eatenAt ?? .distantPast, rhs.item.id)
        }
    }
}
