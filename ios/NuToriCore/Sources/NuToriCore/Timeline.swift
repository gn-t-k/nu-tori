import Foundation

public struct Timeline: Sendable {
    /// タイムラインに並べる日で、日のまとめで送れる日でもある
    public let dayRange: ClosedRange<CalendarDay>

    public init(input: Input, firstDay: CalendarDay, today: CalendarDay) {
        let weightRecordsByDay = Dictionary(
            grouping: input.weightRecords.filter { $0.day >= firstDay }, by: \.day)
        let mealsByDay = Dictionary(
            grouping: input.meals.filter { $0.meal.cardDay >= firstDay }, by: \.meal.cardDay)
        let lastDay = ([today] + weightRecordsByDay.keys + mealsByDay.keys).max()!
        let range = firstDay...max(firstDay, lastDay)
        dayRange = range
        days = range.map { day in
            Day(
                day: day,
                items: Self.items(
                    records: weightRecordsByDay[day] ?? [],
                    rejectedLines: input.rejectedLines.filter { $0.record.day == day },
                    meals: mealsByDay[day] ?? [],
                    rejectedMealLines: input.rejectedMealLines.filter { $0.meal.cardDay == day }
                )
            )
        }
    }

    /// 古い日から新しい日へ
    public let days: [Day]

    /// タイムラインに並べる元になるもの。種類が増えたら欄を足す
    public struct Input: Sendable {
        public let weightRecords: [WeightRecord]
        /// サーバーが受け付けなかった体重記録の行
        public let rejectedLines: [RejectedWeightLine]
        public let meals: [MealCard]
        /// サーバーが受け付けなかった食事の行
        public let rejectedMealLines: [RejectedMealLine]

        public init(
            weightRecords: [WeightRecord],
            rejectedLines: [RejectedWeightLine],
            meals: [MealCard],
            rejectedMealLines: [RejectedMealLine]
        ) {
            self.weightRecords = weightRecords
            self.rejectedLines = rejectedLines
            self.meals = meals
            self.rejectedMealLines = rejectedMealLines
        }
    }

    public struct Day: Hashable, Sendable {
        public let day: CalendarDay
        /// 体重記録は時刻、食事は送った時刻の順。受け付けなかった行は、その位置に入る
        public let items: [Item]

        public init(day: CalendarDay, items: [Item]) {
            self.day = day
            self.items = items
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
                })
        }
    }

    public enum Item: Hashable, Sendable, Identifiable {
        case weightRecord(WeightRecord)
        case rejectedWeightLine(RejectedWeightLine)
        case meal(MealCard)
        case rejectedMealLine(RejectedMealLine)

        public var id: String {
            switch self {
            case .weightRecord(let record): "record-\(record.id.uuidString)"
            case .rejectedWeightLine(let line): "rejection-\(line.record.id.uuidString)"
            case .meal(let card): "meal-\(card.meal.id.uuidString)"
            case .rejectedMealLine(let line): "meal-rejection-\(line.meal.id.uuidString)"
            }
        }
    }

    /// 体重記録と食事を時刻の順に並べ、受け付けなかった体重の行をその位置に入れる
    private static func items(
        records: [WeightRecord],
        rejectedLines: [RejectedWeightLine],
        meals: [MealCard],
        rejectedMealLines: [RejectedMealLine]
    ) -> [Item] {
        var placed =
            (records.map { Placed(record: $0) } + meals.map { Placed(card: $0) }
            + rejectedMealLines.map { Placed(line: $0) })
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

        static func < (lhs: Placed, rhs: Placed) -> Bool {
            (lhs.instant, lhs.eatenAt ?? .distantPast, lhs.item.id)
                < (rhs.instant, rhs.eatenAt ?? .distantPast, rhs.item.id)
        }
    }
}
