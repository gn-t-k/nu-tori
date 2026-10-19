/// 期限の日の結果。開始の日の体重の傾向から期限の日の体重の傾向への変化と、目標体重との差
public struct DeadlineResult: Hashable, Sendable {
    public let deadlineWeightTrendKilograms: Double
    /// 開始からの変化（0.1 kg 単位。減れば負）
    public let changeTenthsOfKilogram: Int
    /// 目標体重まで、あと何 kg だったか（0.1 kg 単位）。届いていれば 0
    public let remainingTenthsOfKilogram: Int

    /// 確定した値を使い、確定する前（期限の日のうち）は、届いている体重の傾向で出し直す。
    /// 減量・増量でない目標と、期限の日以前の体重の傾向が無いときは nil
    init?(goal: Goal, records: GoalRecords) {
        let towardTarget: Double
        guard let weightChange = goal.direction.weightChange,
            let trend = goal.deadlineConfirmation?.deadlineWeightTrendKilograms
                ?? records.trendKilograms(onOrBefore: weightChange.deadlineDay)
        else { return nil }
        switch goal.direction {
        case .lose: towardTarget = trend - goal.targetWeightKilograms
        case .gain: towardTarget = goal.targetWeightKilograms - trend
        case .maintain: return nil
        }
        deadlineWeightTrendKilograms = trend
        changeTenthsOfKilogram = GoalText.tenths(trend - goal.startingWeightTrendKilograms)
        remainingTenthsOfKilogram = max(GoalText.tenths(towardTarget), 0)
    }

    /// 「開始から −3.6 kg・目標まであと 0.4 kg」
    public var text: String {
        "開始から \(GoalText.signedKilograms(tenths: changeTenthsOfKilogram))・目標まであと \(GoalText.kilograms(tenths: remainingTenthsOfKilogram))"
    }
}
