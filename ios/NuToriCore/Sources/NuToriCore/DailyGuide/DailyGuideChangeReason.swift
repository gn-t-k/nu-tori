/// 1日の目安が変わった理由と、その文。当たった上限と下限は書かない。
/// 変更の知らせと週の振り返りの次の週の1日の目安が、同じ見直しに同じ理由を言うための1か所。
/// 理由の種類は、サーバーが見直しに書いた主な理由（`WeeklyReview.MainReason`）をそのまま使い、端末では比べ直さない
public enum DailyGuideChangeReason: Hashable, Sendable {
    case expenditureChanged(fromKilocalories: Int, toKilocalories: Int)
    /// 1日に減らす（足す・戻す）分が増えた・減った
    case balanceChanged(Balance, increased: Bool)
    /// 目標に届いたので、1日に減らす（足す）分をなくしていく
    case achieved(Balance)
    /// 期限後の維持に移った
    case movedToMaintenance

    /// 指す推定消費カロリーか目標がまだ届いていなければ nil
    /// - Parameters:
    ///   - mainReason: 新しい1日の目安を書いた見直しの主な理由。まとめて見直したときは、いちばん新しく見直せた週のもの
    ///   - previousGuide: 比べる前の1日の目安
    ///   - guide: 新しい1日の目安
    init?(
        mainReason: WeeklyReview.MainReason, from previousGuide: DailyGuide, to guide: DailyGuide,
        records: GoalRecords
    ) {
        guard
            let previousEstimate = records.expenditureEstimates.first(where: {
                $0.id == previousGuide.expenditureEstimateId
            }),
            let estimate = records.expenditureEstimates.first(where: {
                $0.id == guide.expenditureEstimateId
            }),
            let goal = records.goals.first(where: { $0.id == guide.goalId })
        else { return nil }
        if let previousGoal = goal.goalMovedToMaintenance(from: records.goals),
            previousGoal.id == previousGuide.goalId
        {
            self = .movedToMaintenance
            return
        }
        switch mainReason {
        case .expenditureChange:
            self = .expenditureChanged(
                fromKilocalories: previousEstimate.expenditureKilocalories,
                toKilocalories: estimate.expenditureKilocalories)
        case .balanceChange:
            let balance = Balance(goal.direction)
            if let achievement = goal.achievement, achievement.achievedDay < guide.effectiveDay {
                self = .achieved(balance)
            } else {
                self = .balanceChanged(
                    balance,
                    increased: abs(estimate.expenditureKilocalories - guide.energyKilocalories)
                        > abs(
                            previousEstimate.expenditureKilocalories
                                - previousGuide.energyKilocalories))
            }
        }
    }

    public var text: String {
        switch self {
        case .expenditureChanged(let from, let to):
            "推定消費カロリーが \(NutritionText.number(.exactly(Double(from)), of: .energyKcal)) から \(NutritionText.kilocalories(to)) に\(to < from ? "下がった" : "上がった")ためです。"
        case .balanceChanged(.maintain, let increased):
            "体重の傾向に合わせて、1日に戻す分を\(increased ? "増やした" : "減らした")ためです。"
        case .balanceChanged(let balance, true):
            "期限までの日が減り、1日に\(balance.name)を増やしたためです。"
        case .balanceChanged(let balance, false):
            "予定より進んでいるので、1日に\(balance.name)を減らしたためです。"
        case .achieved(let balance):
            "目標に届いたので、1日に\(balance.name)をなくしていくためです。"
        case .movedToMaintenance:
            "今の体重を保つ目標に切り替えたためです。"
        }
    }

    /// 1日に◯◯分。目標の向きで呼び分ける
    public enum Balance: Hashable, Sendable {
        case lose
        case gain
        case maintain

        init(_ direction: Goal.Direction) {
            switch direction {
            case .lose: self = .lose
            case .gain: self = .gain
            case .maintain: self = .maintain
            }
        }

        var name: String {
            switch self {
            case .lose: "減らす分"
            case .gain: "足す分"
            case .maintain: "戻す分"
            }
        }
    }
}
