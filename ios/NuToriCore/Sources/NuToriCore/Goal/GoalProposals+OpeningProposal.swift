public import NuToriAPI

extension GoalProposals.WeightChange {
    /// 目標案のページを開いたときに選んでおく案。標準が出れば標準（「おすすめ」を付ける）、出なければ出せる案のうち最もゆるい案。
    /// 1つも出せなければ nil。自分で決める目標体重の初期値も、この案の目標体重
    public var openingProposal: GoalProposals.OfferedProposal? {
        offeredProposals.first { $0.pace == .standard } ?? offeredProposals.first
    }

    /// 減量で、出せる案が1つも無いか、受け付ける目標体重が無い
    var offersNothing: Bool {
        offeredProposals.isEmpty || acceptedTargetWeightRange == nil
    }
}
