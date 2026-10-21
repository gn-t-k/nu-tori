import Foundation

public struct Timeline: Sendable {
    /// タイムラインに並べる日で、日のまとめで送れる日でもある
    public let dayRange: ClosedRange<CalendarDay>

    public init(input: Input, firstDay: CalendarDay, today: CalendarDay) {
        let weightRecordsByDay = Dictionary(
            grouping: input.weightRecords.filter { $0.day >= firstDay }, by: \.day)
        // 1日の丸と日のまとめには、カードを置く日でなく、食事の日（撮った時刻と食事の時差から出した日）に入れる。
        // 食事の日が使い始めた日より前の食事は、カードは並べても、丸にも日のまとめにも入れない
        let mealsByEatenDay = Dictionary(
            grouping: input.meals.filter { $0.meal.day >= firstDay }, by: \.meal.day)
        // 答えた体重の知らせは並べない。記録したことは体重の行で分かるため。
        // 対象の日付を持たない知らせ（目標を立てる）は、下で出した日に置く
        let noticesByDay = Dictionary(
            grouping: input.notices.compactMap { notice -> (day: CalendarDay, notice: Notice)? in
                guard notice.response == nil, let targetDay = notice.targetDay,
                    targetDay >= firstDay
                else { return nil }
                return (targetDay, notice)
            },
            by: \.day)
        // 目標を立てる知らせは、答えたあとも（目標が決まった）カードを残す。
        // 出したときのタイムゾーンの日に置き、使い始めた日より前なら使い始めた日に置く
        let goalSetupNotice = input.notices.first { $0.kind == .goalSetup }
        let goalSetupNoticeDay = goalSetupNotice.map {
            max(CalendarDay(containing: $0.issuedAt, in: $0.timeZone), firstDay)
        }
        let rejectedWeightLines = input.rejectedLines.compactMap(\.weightLine)
        // 食事・料理・材料の行のうち、タイムラインに置くもの（食事が消えている、食事そのものの行）だけ。ほかは食事の画面と料理の画面に出す
        let cardsByMealId = Dictionary(
            input.meals.map { ($0.meal.id, $0) }, uniquingKeysWith: { first, _ in first })
        let rejectedMealLines = input.rejectedLines.compactMap(\.mealLine).filter {
            $0.placement(in: cardsByMealId[$0.meal.id]) == .timeline
        }
        undelivered = input.undelivered
        notices = input.notices
        self.goalSetupNotice = goalSetupNotice
        let conversation = ConversationItems(
            input.conversation, rejectedLines: input.rejectedLines.compactMap(\.sentTextLine),
            cardsByMealId: cardsByMealId, undelivered: input.undelivered)
        // 吹き出しにつないだ文章の食事は、単独のカードとして並べない
        let mealsByDay = Dictionary(
            grouping: input.meals.filter {
                $0.meal.cardDay >= firstDay && !conversation.joinedMealIds.contains($0.meal.id)
            }, by: \.meal.cardDay)
        let bubblesByDay = Dictionary(
            grouping: conversation.bubbles.filter { $0.sentText.day >= firstDay },
            by: \.sentText.day)
        let ring = { (day: CalendarDay) in
            DayRing(
                hasWeightRecord: weightRecordsByDay[day] != nil,
                food: DayFood(meals: mealsByEatenDay[day] ?? []),
                dailyGuide: DailyGuideForDay(
                    on: day, goals: input.goals, dailyGuides: input.dailyGuides)?.dailyGuide)
        }
        let weeklyReviewsByDay = Dictionary(
            grouping: Self.weeklyReviewItems(input: input, firstDay: firstDay, ring: ring),
            by: \.day)
        let goalNoticesByDay = Dictionary(
            grouping: GoalNotice.notices(
                goals: input.goals,
                currentGoalId: CurrentGoal(
                    today: today, goals: input.goals, dailyGuides: input.dailyGuides)?.goal.id),
            by: { max(CalendarDay(containing: $0.issuedAt, in: $0.timeZone), firstDay) })
        let subscriptionNoticesByDay = Dictionary(
            grouping: input.subscriptionNotices.filter { $0.day >= firstDay }, by: \.day)
        let lastDay =
            ([today] + weightRecordsByDay.keys + mealsByDay.keys + noticesByDay.keys
            + bubblesByDay.keys + [goalSetupNoticeDay].compactMap(\.self)
            + weeklyReviewsByDay.keys + goalNoticesByDay.keys).max()!
        let range = firstDay...max(firstDay, lastDay)
        dayRange = range
        days = range.map { day in
            Day(
                day: day,
                items: (subscriptionNoticesByDay[day] ?? []).map { .subscriptionNotice($0) }
                    + Self.items(
                        records: weightRecordsByDay[day] ?? [],
                        rejectedLines: rejectedWeightLines.filter { $0.record.day == day },
                        meals: mealsByDay[day] ?? [],
                        rejectedMealLines: rejectedMealLines.filter { $0.meal.cardDay == day },
                        notices: (noticesByDay[day] ?? []).compactMap {
                            NoticeCard(unanswered: $0.notice, today: today)
                        },
                        goalSetupNotice: goalSetupNoticeDay == day ? goalSetupNotice : nil,
                        weeklyReviews: weeklyReviewsByDay[day] ?? [],
                        goalNotices: goalNoticesByDay[day] ?? [],
                        bubbles: bubblesByDay[day] ?? [],
                        rejectedSentTextLines: conversation.separateLines.filter {
                            $0.sentText.day == day
                        },
                        replies: conversation.replies
                    ),
                food: DayFood(meals: mealsByEatenDay[day] ?? []),
                dailyGuide: DailyGuideForDay(
                    on: day, goals: input.goals, dailyGuides: input.dailyGuides)?.dailyGuide
            )
        }
    }

    /// 古い日から新しい日へ
    public let days: [Day]

    /// 日が1つも並んでいなければ無い
    public var newestDay: CalendarDay? {
        days.last?.day
    }

    /// まだ届いていない記録か。薄く描き、VoiceOver で「送信待ち」と添える
    public func isUndelivered(_ item: Item) -> Bool {
        undelivered.contains(item)
    }

    private let undelivered: UndeliveredRecords
    private let notices: [Notice]

    /// タイムラインにカードを置いた、目標を立てる知らせ（答えたものも含む）。知らせがまだ無ければ nil
    public let goalSetupNotice: Notice?

    /// 帯の下に1行で示す、答えていない知らせ（今日の体重の知らせと、目標を立てる知らせ）。出した時刻の古い順
    public var unansweredNoticeLines: [UnansweredNoticeLine] {
        UnansweredNoticeLine.lines(
            weightNoticeAwaitingAnswer: noticeAwaitingAnswer, notices: notices)
    }

    /// 今日の答えていない体重の知らせ。画面の上へ流れて見えないときに、帯の下の1行で示す。
    /// 答えていない形のカードは、対象の日付が今日の知らせにだけあり、今日の日に並ぶので、新しい日から探す
    public var noticeAwaitingAnswer: NoticeCard? {
        days.reversed().lazy.flatMap(\.items)
            .compactMap { item -> NoticeCard? in
                if case .notice(let card) = item, card.form == .awaitingAnswer { card } else { nil }
            }
            .first
    }

    /// 体重の画面とタイムラインで同じ日を使う
    public static func firstDay(
        startedDay: CalendarDay?, weightRecords: [WeightRecord], today: CalendarDay
    ) -> CalendarDay {
        startedDay ?? weightRecords.map(\.day).min() ?? today
    }

    /// 記録忘れの通知を押して開いたときに着く位置。その知らせが並んでいなければ、タイムラインのいちばん下
    public func landing(for reminder: ReminderLanding) -> Landing {
        switch reminder {
        case .notice(let noticeId):
            let item = days.lazy.flatMap(\.items).first { item in
                if case .notice(let card) = item { card.notice.id == noticeId } else { false }
            }
            guard let item else { return .end }
            return .item(item.id)
        case .timelineEnd:
            return .end
        }
    }

    public enum ItemSpacing: Equatable, Sendable {
        case close
        case apart
    }

    /// タイムラインの項目の話し手
    public enum Speaker: Equatable, Sendable {
        case me
        case ai
        case app
    }

    public enum Landing: Equatable, Sendable {
        /// そのカードの位置
        case item(Item.ID)
        /// タイムラインのいちばん下
        case end
    }

    /// タイムラインに並べる元になるもの。種類が増えたら欄を足す
    public struct Input: Sendable {
        /// 目標・1日の目安・推定消費カロリー・週の見直し・体重の傾向・体重記録。1日の丸と日のまとめを、その日の1日の目安と比べ、
        /// 振り返りのカードと変更の知らせを組むために引く。目標・1日の目安・推定消費カロリーがまだ届いていない見直しも含む
        public let goalRecords: GoalRecords
        /// サーバーが受け付けなかった体重記録と食事の行
        public let rejectedLines: [RejectedLine]
        public let meals: [MealCard]
        /// 答えた知らせも含む
        public let notices: [Notice]
        public let undelivered: UndeliveredRecords
        public let conversation: Conversation
        /// 無料体験とサブスクリプションの知らせ（`SubscriptionNotice.notices`）。その日の先頭に置く
        public let subscriptionNotices: [SubscriptionNotice]

        public init(
            goalRecords: GoalRecords,
            rejectedLines: [RejectedLine],
            meals: [MealCard],
            notices: [Notice],
            undelivered: UndeliveredRecords,
            conversation: Conversation,
            subscriptionNotices: [SubscriptionNotice]
        ) {
            self.subscriptionNotices = subscriptionNotices
            self.goalRecords = goalRecords
            self.rejectedLines = rejectedLines
            self.meals = meals
            self.notices = notices
            self.undelivered = undelivered
            self.conversation = conversation
        }

        /// 送り待ちを含む
        public var weightRecords: [WeightRecord] { goalRecords.weightRecords }
        /// 閉じた目標も含む
        var goals: [Goal] { goalRecords.goals }
        /// 目標がまだ届いていない1日の目安も含む
        var dailyGuides: [DailyGuide] { goalRecords.dailyGuides }
    }

    public struct Day: Hashable, Sendable {
        public let day: CalendarDay
        /// 体重記録は時刻、食事は送った時刻、知らせは出した時刻、送った文章は送った時刻の順。文章の食事は、その文章の吹き出しにつなぐ。
        /// 受け付けなかった行は、その位置に入る。返事は、応える送った文章のすぐあと
        public let items: [Item]
        /// この日の食べた量。この日に食べた（食事の日がこの日の）食事から出す。カードを置く日の食事とは限らない
        public let food: DayFood
        /// この日の食べた量を比べる1日の目安（`DailyGuideForDay`）。目標を立てる前の日と、目安がまだ届いていない日は nil で、比べない
        public let dailyGuide: DailyGuide?

        public init(day: CalendarDay, items: [Item], food: DayFood, dailyGuide: DailyGuide?) {
            self.day = day
            self.items = items
            self.food = food
            self.dailyGuide = dailyGuide
        }

        public var representativeWeight: RepresentativeWeight? {
            RepresentativeWeight(
                sameDayRecords: items.compactMap {
                    if case .weightRecord(let record) = $0 { record } else { nil }
                })
        }

        /// 話し手の替わり目を空けて、自分の吹き出しのすぐ下の返事が、前の吹き出しの続きに見えないようにする。日の見出しは話し手ではないので、日の最初の項目は詰める。
        /// 会話の区切りを持たず、隣り合う2つだけで決める。日をまたぐ会話や、あとから入った食事で、間がずれないため（#449 の解決コメント）
        public func spacing(before item: Item) -> ItemSpacing {
            guard let index = items.firstIndex(of: item), index > 0 else { return .close }
            return items[index - 1].speaker == item.speaker ? .close : .apart
        }

        /// 1日の丸の帯に出す、この日の丸
        public var ring: DayRing {
            DayRing(
                hasWeightRecord: items.contains {
                    if case .weightRecord = $0 { true } else { false }
                },
                food: food, dailyGuide: dailyGuide)
        }
    }

    public enum Item: Hashable, Sendable, Identifiable {
        case weightRecord(WeightRecord)
        case rejectedWeightLine(RejectedWeightLine)
        case meal(MealCard)
        case rejectedMealLine(RejectedMealLine)
        case notice(NoticeCard)
        /// 目標を立てる知らせのカード。答えたあとも残り、目標が決まると決めた目標を示す形になる（形は画面が目標の記録で決める）
        case goalSetupNotice(Notice)
        /// 週の振り返りのカード。見直した時刻に置く
        case weeklyReviewCard(WeeklyReviewCard)
        /// 1日の目安の変更の知らせ。振り返りのカードのすぐ下に置く
        case dailyGuideChangeNotice(DailyGuideChangeNotice)
        /// 目標の達成・期限・期限後の維持の知らせ
        case goalNotice(GoalNotice)
        case sentText(SentTextBubble)
        /// 文章を送る（作る書き込み）を受け付けなかった1行。吹き出しを外した位置に出す
        case rejectedSentTextLine(RejectedSentTextLine)
        case reply(TimelineReply)
        /// 無料体験とサブスクリプションの知らせ。その日の先頭に置く
        case subscriptionNotice(SubscriptionNotice)

        /// 受け付けなかった1行は、自分が書いた記録や文章の代わりに出るので、自分にする
        public var speaker: Speaker {
            switch self {
            case .weightRecord, .rejectedWeightLine, .meal, .rejectedMealLine, .sentText,
                .rejectedSentTextLine:
                .me
            case .reply: .ai
            case .notice, .goalSetupNotice, .weeklyReviewCard, .dailyGuideChangeNotice, .goalNotice,
                .subscriptionNotice:
                .app
            }
        }

        /// 知らせのカードなら、その知らせの ID
        var noticeId: UUID? {
            switch self {
            case .notice(let card): card.notice.id
            case .goalSetupNotice(let notice): notice.id
            // 同期で届いた記録から描くカードは、知らせの行（`Notice`）でない
            case .weightRecord, .rejectedWeightLine, .meal, .rejectedMealLine, .sentText,
                .rejectedSentTextLine, .reply, .weeklyReviewCard, .dailyGuideChangeNotice,
                .goalNotice, .subscriptionNotice:
                nil
            }
        }

        public var id: String {
            switch self {
            case .weightRecord(let record): "record-\(record.id.uuidString)"
            case .rejectedWeightLine(let line): "rejection-\(line.record.id.uuidString)"
            case .meal(let card): "meal-\(card.meal.id.uuidString)"
            case .rejectedMealLine(let line): "meal-rejection-\(line.recordId.uuidString)"
            case .notice(let card): "notice-\(card.notice.id.uuidString)"
            case .goalSetupNotice(let notice): "notice-\(notice.id.uuidString)"
            case .sentText(let bubble): "sent-text-\(bubble.sentText.id.uuidString)"
            case .rejectedSentTextLine(let line):
                "sent-text-rejection-\(line.sentText.id.uuidString)"
            case .reply(let reply): "reply-\(reply.id.uuidString)"
            case .weeklyReviewCard(let card): "weekly-review-\(card.review.id.uuidString)"
            case .dailyGuideChangeNotice(let notice):
                "daily-guide-change-\(notice.review.id.uuidString)"
            case .goalNotice(let notice):
                "goal-\(notice.kind.idPrefix)-\(notice.goal.id.uuidString)"
            case .subscriptionNotice(let notice): "subscription-\(notice.kind.idSuffix)"
            }
        }
    }

    /// 体重記録と食事と知らせを時刻の順に並べ、受け付けなかった体重の行をその位置に入れる
    private static func items(
        records: [WeightRecord],
        rejectedLines: [RejectedWeightLine],
        meals: [MealCard],
        rejectedMealLines: [RejectedMealLine],
        notices: [NoticeCard],
        goalSetupNotice: Notice?,
        weeklyReviews: [WeeklyReviewItems],
        goalNotices: [GoalNotice],
        bubbles: [SentTextBubble],
        rejectedSentTextLines: [RejectedSentTextLine],
        replies: [UUID: [TimelineReply]]
    ) -> [Item] {
        var placed =
            (records.map { Placed(record: $0) } + meals.map { Placed(card: $0) }
            + rejectedMealLines.map { Placed(line: $0) } + notices.map { Placed(notice: $0) }
            + [goalSetupNotice].compactMap(\.self).map { Placed(goalSetupNotice: $0) }
            + weeklyReviews.map { Placed(weeklyReviewCard: $0.card) }
            + goalNotices.map { Placed(goalNotice: $0) }
            + bubbles.map { Placed(bubble: $0) } + rejectedSentTextLines.map { Placed(line: $0) })
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
        var items = placed.map(\.item)
        for review in weeklyReviews {
            guard let notice = review.changeNotice,
                let cardIndex = items.firstIndex(of: .weeklyReviewCard(review.card))
            else { continue }
            items.insert(.dailyGuideChangeNotice(notice), at: cardIndex + 1)
        }
        for bubble in bubbles {
            guard let sentReplies = replies[bubble.sentText.id],
                let bubbleIndex = items.firstIndex(of: .sentText(bubble))
            else { continue }
            items.insert(contentsOf: sentReplies.map { .reply($0) }, at: bubbleIndex + 1)
        }
        return items
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
            self.init(
                instant: card.meal.sentAt, eatenAt: card.meal.eatenAt, item: .meal(card))
        }

        init(line: RejectedMealLine) {
            self.init(
                instant: line.meal.sentAt, eatenAt: line.meal.eatenAt,
                item: .rejectedMealLine(line))
        }

        init(bubble: SentTextBubble) {
            self.init(instant: bubble.sentText.sentAt, eatenAt: nil, item: .sentText(bubble))
        }

        init(line: RejectedSentTextLine) {
            self.init(
                instant: line.sentText.sentAt, eatenAt: nil, item: .rejectedSentTextLine(line))
        }

        init(notice: NoticeCard) {
            self.init(instant: notice.notice.issuedAt, eatenAt: nil, item: .notice(notice))
        }

        init(goalSetupNotice notice: Notice) {
            self.init(instant: notice.issuedAt, eatenAt: nil, item: .goalSetupNotice(notice))
        }

        init(weeklyReviewCard card: WeeklyReviewCard) {
            self.init(
                instant: card.review.reviewedAt, eatenAt: nil, item: .weeklyReviewCard(card))
        }

        init(goalNotice notice: GoalNotice) {
            self.init(instant: notice.issuedAt, eatenAt: nil, item: .goalNotice(notice))
        }

        static func < (lhs: Placed, rhs: Placed) -> Bool {
            (lhs.instant, lhs.eatenAt ?? .distantPast, lhs.item.id)
                < (rhs.instant, rhs.eatenAt ?? .distantPast, rhs.item.id)
        }
    }
}
