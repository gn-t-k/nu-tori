/// 1日の目安が変わった理由と、その文。当たった上限と下限は書かない。
/// 変更の知らせと週の振り返りの次の週の1日の目安が、同じ見直しに同じ理由を言うための1か所。
/// 理由の種類は、サーバーが見直しに書いた主な理由（`WeeklyReview.MainReason`）をそのまま使い、端末では比べ直さない
public enum DailyGuideChangeReason: Hashable, Sendable {
    case expenditureChanged(fromKilocalories: Int, toKilocalories: Int)
    /// 減量・増量で、1日の目安と推定消費カロリーの差が広がった・狭まった
    case balanceChanged(Balance, increased: Bool)
    /// 維持で、体重の傾向を目標体重へ戻す差が変わった
    case maintenanceAdjusted(targetKilograms: Double, adjustment: MaintenanceAdjustment)
    /// 目標に届いたので、1日の目安を推定消費カロリーに近づけていく
    case achieved
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
            // 1日の目安から推定消費カロリーを引いた差。負なら目安を推定より下げている
            let previousDifference =
                previousGuide.energyKilocalories - previousEstimate.expenditureKilocalories
            let difference = guide.energyKilocalories - estimate.expenditureKilocalories
            let increased = abs(difference) > abs(previousDifference)
            if let achievement = goal.achievement, achievement.achievedDay < guide.effectiveDay {
                self = .achieved
                return
            }
            switch goal.direction {
            case .lose: self = .balanceChanged(.lose, increased: increased)
            case .gain: self = .balanceChanged(.gain, increased: increased)
            case .maintain:
                self = .maintenanceAdjusted(
                    targetKilograms: goal.targetWeightKilograms,
                    adjustment: MaintenanceAdjustment(
                        increased: increased, differenceKilocalories: difference))
            }
        }
    }

    public var text: String {
        switch self {
        case .expenditureChanged(let from, let to):
            "推定消費カロリーが \(NutritionText.number(.exactly(Double(from)), of: .energyKcal)) から \(NutritionText.kilocalories(to)) に\(to < from ? "下がった" : "上がった")ためです。"
        case .balanceChanged(.lose, true):
            "期限に間に合うよう、1日の目安を推定消費カロリーよりさらに下げたためです。"
        case .balanceChanged(.gain, true):
            "期限に間に合うよう、1日の目安を推定消費カロリーよりさらに上げたためです。"
        case .balanceChanged(.lose, false):
            "体重が予定より早く減っているので、1日の目安を推定消費カロリーに近づけたためです。"
        case .balanceChanged(.gain, false):
            "体重が予定より早く増えているので、1日の目安を推定消費カロリーに近づけたためです。"
        case .maintenanceAdjusted(let kilograms, .lowered):
            "体重の傾向が \(WeightAmountText.kilograms(kilograms)) を上回っているので、1日の目安を推定消費カロリーより下げたためです。"
        case .maintenanceAdjusted(let kilograms, .raised):
            "体重の傾向が \(WeightAmountText.kilograms(kilograms)) を下回っているので、1日の目安を推定消費カロリーより上げたためです。"
        case .maintenanceAdjusted(let kilograms, .eased):
            "体重の傾向が \(WeightAmountText.kilograms(kilograms)) に近づいたので、1日の目安を推定消費カロリーに近づけたためです。"
        case .achieved:
            "目標に届いたので、1日の目安を推定消費カロリーに近づけていくためです。"
        case .movedToMaintenance:
            "今の体重を保つ目標に切り替えたためです。"
        }
    }

    /// 減量か増量か。1日の目安を推定消費カロリーより下げるか上げるか
    public enum Balance: Hashable, Sendable {
        case lose
        case gain
    }

    /// 維持で、1日の目安を推定消費カロリーからどちらへ動かしたか
    public enum MaintenanceAdjustment: Hashable, Sendable {
        /// 体重の傾向が目標体重より上で、目安を推定より下げた
        case lowered
        /// 体重の傾向が目標体重より下で、目安を推定より上げた
        case raised
        /// 体重の傾向が目標体重に近づき、目安を推定に近づけた
        case eased

        /// - Parameters:
        ///   - increased: 1日の目安と推定消費カロリーの差が、前の週より広がったか
        ///   - differenceKilocalories: 1日の目安から推定消費カロリーを引いた差
        init(increased: Bool, differenceKilocalories: Int) {
            if !increased {
                self = .eased
            } else if differenceKilocalories < 0 {
                self = .lowered
            } else {
                self = .raised
            }
        }
    }
}
