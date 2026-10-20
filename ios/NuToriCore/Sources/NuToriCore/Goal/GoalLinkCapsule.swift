/// 左上の目標の入口（仕様の語）。タイムラインのナビゲーションバーの左に置き、押すと目標の画面を開くカプセル。進み具合の輪と1行を出す。目標がないあいだは置かない。
/// 進み具合と残りは、日のまとめと同じく今日の体重の傾向から出す
public struct GoalLinkCapsule: Hashable, Sendable {
    /// 開始の体重から目標体重までの進み具合。0〜1。維持と達成では1（輪は一周）
    public let progress: Double
    /// 「あと 2.8 kg」「72.0 kg を保つ」「達成しました」
    public let text: String

    /// 目標がないときは nil
    /// - Parameter today: 端末の今のタイムゾーンでの今日
    public init?(status: GoalStatus, today: CalendarDay, weightTrend: WeightTrend?) {
        switch status {
        case .noGoal:
            return nil
        case .achievedBeforeDeadline:
            self.init(progress: 1, text: "達成しました")
        case .maintainingAfterDeadline(let goal, _):
            self.init(maintaining: goal)
        case .inProgress(let goal), .deadlineReached(let goal):
            switch goal.direction {
            case .maintain:
                self.init(maintaining: goal)
            case .lose, .gain:
                let wholeTenths = abs(
                    GoalText.tenths(
                        goal.targetWeightKilograms - goal.startingWeightTrendKilograms))
                // 今日以前の体重の傾向がまだ届いていなければ、開始の体重から数えて、入口を消さない
                let remainingTenths =
                    switch GoalProgress(goal: goal, today: today, weightTrend: weightTrend) {
                    case .weightChange(let remainingTenthsOfKilogram, _): remainingTenthsOfKilogram
                    case .maintain, nil: wholeTenths
                    }
                // 輪と残りの kg が食い違わないよう、進み具合も 0.1 kg 単位の残りから出す
                self.init(
                    progress: wholeTenths == 0
                        ? 1 : max(1 - Double(remainingTenths) / Double(wholeTenths), 0),
                    text: "あと \(GoalText.kilograms(tenths: remainingTenths))")
            }
        }
    }

    private init(progress: Double, text: String) {
        self.progress = progress
        self.text = text
    }

    private init(maintaining goal: Goal) {
        self.init(
            progress: 1, text: "\(WeightAmountText.kilograms(goal.targetWeightKilograms)) を保つ")
    }

    /// VoiceOver で輪を読む値。0〜100 に丸める
    public var progressPercent: Int {
        Int((progress * 100).rounded())
    }
}
