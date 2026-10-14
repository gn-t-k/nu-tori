/// 目標を決める要求の答え
public enum GoalDecision: Sendable, Equatable {
    /// 決めた（同じ要求の ID の再送を含む）。記録は、取りに行った変更と同じ道でキャッシュに当てる。
    /// 並びは、立て直しなら閉じた前の目標、新しい目標、1日の目安、初めての目標なら推定消費カロリー
    case decided([SyncChange])
    /// 開始の日か見せていた値が違ったので、決めずにそのときの体重の傾向で出し直した目標案
    case recalculated(GoalProposals)
    /// 自分で決めた目標体重を受け付けないので、決めていない
    case customTargetWeightRejected(
        startedOn: String, reason: TargetWeightLimitReason,
        nearestAcceptedTargetWeightKilograms: Double?)
}
