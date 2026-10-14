public import NuToriAPI

/// 自分で決める目標体重のページの状態
public struct CustomTargetWeight: Sendable, Equatable {
    /// 0.1 kg 単位
    public let kilograms: Double
    public let direction: GoalProposals.Direction
    public let range: GoalProposals.AcceptedTargetWeightRange
    /// 打った値か断られた値を端の値に直したときの理由。直していなければ nil
    public let correctedReason: TargetWeightLimitReason?
    /// 最後に受け取った1日の目安と大変さ。届くまで（`isAssessing`）は前の値を薄くして見せる
    public let assessment: CustomTargetWeightAssessment.Accepted
    /// 自分で決める目標体重の要求の答えを待っている（止めて 0.3 秒たつ前を含む）
    public let isAssessing: Bool

    /// 受け付ける端で − を押せなくする
    public var canDecrease: Bool {
        kilograms > range.minimumKilograms
    }

    /// 受け付ける端で ＋ を押せなくする
    public var canIncrease: Bool {
        kilograms < range.maximumKilograms
    }

    /// 目標体重を替え、答えを待つ形にする
    func moved(to kilograms: Double, correctedReason: TargetWeightLimitReason?)
        -> CustomTargetWeight
    {
        CustomTargetWeight(
            kilograms: kilograms, direction: direction, range: range,
            correctedReason: correctedReason, assessment: assessment, isAssessing: true)
    }

    /// 届いた答え
    func assessed(_ assessment: CustomTargetWeightAssessment.Accepted) -> CustomTargetWeight {
        CustomTargetWeight(
            kilograms: kilograms, direction: direction, range: range,
            correctedReason: correctedReason, assessment: assessment, isAssessing: false)
    }

    /// 答えが届かなかった。前の値を見せたまま待つのをやめる
    func unassessed() -> CustomTargetWeight {
        CustomTargetWeight(
            kilograms: kilograms, direction: direction, range: range,
            correctedReason: correctedReason, assessment: assessment, isAssessing: false)
    }

    /// 計算し直した目標案の受け付ける幅に替える
    func rebased(on range: GoalProposals.AcceptedTargetWeightRange) -> CustomTargetWeight {
        CustomTargetWeight(
            kilograms: kilograms, direction: direction, range: range,
            correctedReason: correctedReason, assessment: assessment, isAssessing: isAssessing)
    }

    /// 受け付ける幅に入れる。外なら端の値と、その端を決めた理由（速い側は幅の理由、遅い側は向きの側に出ない）
    func clamped(_ kilograms: Double) -> (kilograms: Double, reason: TargetWeightLimitReason?) {
        let tenths = (kilograms * 10).rounded() / 10
        let fastestIsMinimum = direction == .lose
        if tenths < range.minimumKilograms {
            return (
                range.minimumKilograms,
                fastestIsMinimum ? range.fastestEndReason : .notOnDirectionSide
            )
        }
        if tenths > range.maximumKilograms {
            return (
                range.maximumKilograms,
                fastestIsMinimum ? .notOnDirectionSide : range.fastestEndReason
            )
        }
        return (tenths, nil)
    }
}
