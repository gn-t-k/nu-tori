public import NuToriAPI

extension GoalProposals {
    /// 目標案のページを開いたときに選んでおく案。標準が出れば標準（「おすすめ」を付ける）、出なければ出せる案のうち最もゆるい案。
    /// 1つも出せないときと維持は nil。自分で決める目標体重の初期値も、この案の目標体重
    public var openingProposal: OfferedProposal? {
        guard case .weightChange(let weightChange) = plan else { return nil }
        let offered = weightChange.offeredProposals
        return offered.first { $0.pace == .standard } ?? offered.first
    }

    /// 減量・増量で、出せる案が1つも無いか、受け付ける目標体重が無い
    var offersNothing: Bool {
        guard case .weightChange(let weightChange) = plan else { return false }
        return weightChange.offeredProposals.isEmpty
            || weightChange.acceptedTargetWeightRange == nil
    }
}
