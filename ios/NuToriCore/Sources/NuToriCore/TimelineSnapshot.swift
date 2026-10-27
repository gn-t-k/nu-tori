public import Foundation

/// タイムラインの画面が描く値。キャッシュの記録と端末だけが持つもの（受け付けなかった1行・送り待ちの見え方・受け取っている途中の返事）を、今日と今で組む。
/// タイムラインから潜る画面（体重・目標・週の振り返り・食事）と日のまとめにも、ここから渡す
public struct TimelineSnapshot: Sendable {
    public let today: CalendarDay
    /// 初回の取得を終えるまでは、記録がそろっていないので組まない
    public let timeline: Timeline?
    /// 体重の画面とタイムラインで同じ日を使う
    public let firstDay: CalendarDay
    /// 送り待ちを含む
    public let weightRecords: [WeightRecord]
    /// 同期で届いた体重の傾向。体重記録が無ければ nil
    public let weightTrend: WeightTrend?
    public let rejectedLines: [RejectedLine]
    public let meals: [MealCard]
    /// 送った文章・その状態・返事・見守る要求で受け取っている途中の返事
    public let conversation: Timeline.Conversation
    /// 目標・1日の目安・推定消費カロリー・週の見直し・体重の傾向・体重記録
    public let goalRecords: GoalRecords
    public let currentGoal: CurrentGoal?
    /// 端末の今日でのサブスクリプションの状態。状態がまだ届いていなければ nil
    public let subscriptionStanding: SubscriptionStanding?

    /// 記録は、読めない行を飛ばしてキャッシュから読んだもの
    /// - Parameters:
    ///   - notices: 答えた知らせも含む
    ///   - goals: 閉じた目標も含む
    ///   - dailyGuides: 目標がまだ届いていない1日の目安も含む
    ///   - weeklyReviews: 指す推定消費カロリー・1日の目安・目標がまだ届いていない見直しも含む
    ///   - subscriptionStatus: まだ届いていなければ nil（知らせを出さず、入力欄も押せるまま）
    ///   - undelivered: まだ届いていない記録（薄く描く）
    ///   - now: 無料体験とサブスクリプションの状態を、端末の今で決める
    public init(
        weightRecords: [WeightRecord], weightTrend: WeightTrend?, initialPull: InitialPull,
        rejectedLines: [RejectedLine], meals: [MealCard], notices: [Notice], goals: [Goal],
        dailyGuides: [DailyGuide], weeklyReviews: [WeeklyReview],
        expenditureEstimates: [ExpenditureEstimate], subscriptionStatus: SubscriptionStatus?,
        undelivered: UndeliveredRecords, conversation: Timeline.Conversation,
        today: CalendarDay, now: Date, timeZone: TimeZone
    ) {
        let goalRecords = GoalRecords(
            goals: goals, dailyGuides: dailyGuides, expenditureEstimates: expenditureEstimates,
            weeklyReviews: weeklyReviews, weightTrend: weightTrend, weightRecords: weightRecords)
        let firstDay = Timeline.firstDay(
            startedDay: initialPull.startedDay, weightRecords: weightRecords, today: today)
        self.today = today
        self.firstDay = firstDay
        self.weightRecords = weightRecords
        self.weightTrend = weightTrend
        self.rejectedLines = rejectedLines
        self.meals = meals
        self.conversation = conversation
        self.goalRecords = goalRecords
        currentGoal = CurrentGoal(today: today, goals: goals, dailyGuides: dailyGuides)
        subscriptionStanding = subscriptionStatus.map {
            SubscriptionStanding(status: $0, now: now, timeZone: timeZone)
        }
        switch initialPull {
        case .inProgress:
            timeline = nil
        case .completed:
            timeline = Timeline(
                input: Timeline.Input(
                    goalRecords: goalRecords, rejectedLines: rejectedLines, meals: meals,
                    notices: notices, undelivered: undelivered, conversation: conversation,
                    subscriptionNotices: subscriptionStatus.map {
                        SubscriptionNotice.notices(
                            status: $0, now: now, timeZone: timeZone, firstSignInDay: firstDay)
                    } ?? []),
                firstDay: firstDay, today: today)
        }
    }

    public enum InitialPull: Sendable {
        case inProgress
        /// 使い始めた日は、サーバーで決まるまで無い
        case completed(startedDay: CalendarDay?)

        fileprivate var startedDay: CalendarDay? {
            switch self {
            case .inProgress: nil
            case .completed(let startedDay): startedDay
            }
        }
    }

    /// 帯の週。読み込み中は、今日の週を空の丸にする（使い始めた日は、取り終えてから入る）
    public var ringWeeks: [RingStrip.Week] {
        if let timeline {
            return RingStrip(timeline: timeline).weeks
        }
        let monday = today.startOfWeek
        return RingStrip(
            timeline: Timeline(
                input: Timeline.Input(
                    goalRecords: GoalRecords(
                        goals: [], dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                        weightTrend: nil, weightRecords: []), rejectedLines: [], meals: [],
                    notices: [], undelivered: .none, conversation: .none, subscriptionNotices: []),
                firstDay: monday,
                today: today)
        ).weeks
    }

    public var weightRecordedToday: Bool {
        weightRecords.contains { $0.day == today }
    }

    /// サブスクリプション切れのあいだは、入力欄を押せなくし、返事を作り直す操作を出さない
    public var requiresSubscription: Bool {
        subscriptionStanding?.isExpired ?? false
    }

    /// 開いたときの状態で課金画面を開く求め。テストユーザーと、状態がまだ届いていないときは nil
    public func paywallRequest(from entry: ClientUsageEvent.PaywallEntry) -> PaywallRequest? {
        subscriptionStanding.flatMap {
            PaywallRequest(entry: entry, standing: $0, today: today)
        }
    }

    /// 日のまとめと体重の画面に「目標を立てる」を置くか。目標が無く、知らせのカードがタイムラインにあるときだけ置く
    public var offersGoalSetup: Bool {
        currentGoal == nil && timeline?.goalSetupNotice != nil
    }

    public var goalStatus: GoalStatus {
        GoalStatus(currentGoal: currentGoal?.goal, goals: goalRecords.goals)
    }

    /// 左上の目標の入口。目標がないあいだは nil
    public var goalLink: GoalLinkCapsule? {
        GoalLinkCapsule(status: goalStatus, today: today, weightTrend: weightTrend)
    }

    /// 目標の画面の中身。目標がないときは nil で、目標の画面を開かない
    public var goalOverview: GoalOverview? {
        GoalOverview(today: today, records: goalRecords)
    }

    /// 週の振り返りの中身。その週を含む目標が無ければ nil
    public func weekRecap(monday: CalendarDay) -> WeekRecap? {
        WeekRecap(weekOf: monday, today: today, records: goalRecords, meals: meals)
    }

    /// 体重の画面の目標までの道のり。目標がなければ nil
    public var weightGoalPath: WeightGoalPath? {
        WeightGoalPath(status: goalStatus, today: today, records: goalRecords)
    }

    /// 体重の画面の、最近4週の傾向のグラフ
    public var weightTrendChart: WeightTrendChart {
        WeightTrendChart(
            weightRecords: weightRecords, trend: weightTrend, firstDay: firstDay, today: today,
            goal: currentGoal?.goal)
    }

    /// 「すべての記録」の行。使い始めた日からの1日1行
    public var weightHistory: [RepresentativeWeight] {
        DailyWeightRecords(weightRecords: weightRecords, firstDay: firstDay).all
    }

    /// 食事の画面に描くカード。消えていれば nil
    public func mealCard(id: UUID) -> MealCard? {
        meals.first { $0.meal.id == id }
    }

    /// 文章の食事の送った文章。写真の食事と、送った文章がまだ届いていない文章の食事は nil
    public func sentText(of card: MealCard) -> SentText? {
        card.meal.sentTextId.flatMap { sentTextId in
            conversation.sentTexts.first { $0.id == sentTextId }
        }
    }
}
