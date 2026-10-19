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
                // 体重の傾向は最後の体重記録の日で終わるので、今日以前で最も新しい日の値を今日の傾向にする（`GoalProgress` と同じ）。
                // まだ届いていなければ開始の体重の傾向にして、入口を消さない
                let trend =
                    weightTrend?.days.last { $0.day <= today }?.kilograms
                    ?? goal.startingWeightTrendKilograms
                let whole = goal.targetWeightKilograms - goal.startingWeightTrendKilograms
                let moved = trend - goal.startingWeightTrendKilograms
                // 目標体重を越えたら 0 で止める（`GoalProgress` と同じ）
                let remainingTenths = max(
                    Int((abs(goal.targetWeightKilograms - trend) * 10).rounded()), 0)
                let overshot = whole == 0 || moved / whole >= 1
                self.init(
                    progress: whole == 0 ? 1 : min(max(moved / whole, 0), 1),
                    text: "あと \(NoticeAmountText.kilograms(tenths: overshot ? 0 : remainingTenths))"
                )
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
