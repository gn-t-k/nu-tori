/// 目標の下見の答え
public struct GoalSetupPreview: Sendable, Equatable {
    /// 推定消費カロリーを記録から逆算できるか。初めての目標のときだけ付く
    public let canBackCalculate: Bool?
    /// 減量の目標案を1つでも出せるか。減量で、推定消費カロリーと体重の傾向を出せたときだけ付く
    public let canOfferLoseProposals: Bool?

    public init(canBackCalculate: Bool?, canOfferLoseProposals: Bool?) {
        self.canBackCalculate = canBackCalculate
        self.canOfferLoseProposals = canOfferLoseProposals
    }
}
