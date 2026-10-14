import NuToriAPI
import NuToriCore
import SwiftUI

/// 目標案のページ。見出し「12月24日までの目標を選んでください」と、ゆるめ・標準・ハードの3つの「選ぶ」行。
/// 「おすすめ」は標準に付け、出せない案は押せない灰色の枠に理由を書く。選んでから「この目標で始める」で決まる。
/// 案が届くまでは、届く場所の高さを先に取り、その中央に回る印を出す（届いても「戻る」「閉じる」が動かない）
struct GoalSetupProposalsPage: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GoalSetupUsedValuesLine(content: content, actions: actions)
            Text("\(GoalSetupDayText.monthDay(content.deadline))までの目標を選んでください")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal-setup-proposals-heading")
            Group {
                if case .weightChange(let weightChange)? = content.proposals?.plan {
                    rows(weightChange)
                } else {
                    waitingRows
                }
            }
            .opacity(isDeciding ? 0.4 : 1)
            .disabled(isDeciding)
            if content.showsRecalculated {
                Text("新しい体重で計算し直しました。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if content.unreachableRequest == .decision {
                Text(GoalSetupUnreachableText.decision)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("goal-setup-unreachable")
            }
            GoalSetupStartButton(
                title: "この目標で始める", identifier: "goal-setup-proposal-start",
                isDeciding: content.isDeciding, decide: actions.decide
            )
            .disabled(content.proposals == nil)
            GoalSetupFooter(page: content.page, goBack: actions.goBack) {
                if content.unreachableRequest == .decision {
                    GoalSetupRetryButton(retry: actions.retry)
                } else {
                    Button("目標体重を自分で決める", action: actions.openCustomTargetWeight)
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("goal-setup-open-custom")
                        // 届くまでは場所だけを取り、届いてもページの下の行を動かさない
                        .opacity(content.proposals == nil ? 0 : 1)
                        .disabled(content.proposals == nil)
                }
            }
            .opacity(isDeciding ? 0.4 : 1)
            .disabled(isDeciding)
        }
    }

    private var isDeciding: Bool {
        content.isDeciding
    }

    private func rows(_ weightChange: GoalProposals.WeightChange) -> some View {
        VStack(spacing: 8) {
            ForEach(weightChange.proposals, id: \.pace) { proposal in
                switch proposal {
                case .offered(let offered):
                    GoalProposalRow(
                        proposal: offered,
                        isSelected: offered.pace == content.selectedPace,
                        isRecommended: offered.pace == .standard
                    ) {
                        actions.selectPace(offered.pace)
                    }
                case .unavailable(let pace, let reason):
                    unavailableRow(pace: pace, reason: reason)
                }
            }
        }
    }

    /// 案が届くまで。届く3つの行と同じ高さを取り、その中央に回る印と「目標案を計算しています…」を出す
    private var waitingRows: some View {
        VStack(spacing: 8) {
            ForEach(GoalProposals.Pace.allCases, id: \.self) { pace in
                GoalProposalRow(
                    proposal: GoalProposals.OfferedProposal(
                        pace: pace, targetWeightKilograms: 70.0,
                        dailyGuide: DailyGuidePlan(
                            energyKilocalories: 2000, proteinGrams: 0, fatGrams: 0,
                            carbohydrateGrams: 0),
                        difficulty: pace, dailyGuideDifferenceKilocalories: -400),
                    isSelected: false,
                    isRecommended: pace == .standard, select: {})
            }
        }
        .hidden()
        .overlay {
            HStack(spacing: 8) {
                ProgressView()
                Text("目標案を計算しています…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("goal-setup-proposals-waiting")
        }
    }

    /// 出せない案。押せない灰色の枠に理由を書く
    private func unavailableRow(pace: GoalProposals.Pace, reason: GoalProposals.UnavailableReason)
        -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            Text(GoalSetupDifficultyText.paceName(pace))
                .font(.subheadline.weight(.semibold))
            Text(unavailableText(reason))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Color(.separator), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goal-setup-proposal-unavailable")
    }

    private func unavailableText(_ reason: GoalProposals.UnavailableReason) -> String {
        switch reason {
        case .dailyGuideBelowMinimum: "1日の目安が 1,200 kcal を下回るため、出せません"
        case .unknown: "出せません"
        }
    }
}

/// 目標案の「選ぶ」行。左に選んだ印、案の名前（標準には「おすすめ」）と大変さのひとこと、右に目標体重と1日の目安。
/// 大きな文字では右の値を下に回し、どの文も折り返して全文を出す
private struct GoalProposalRow: View {
    let proposal: GoalProposals.OfferedProposal
    let isSelected: Bool
    let isRecommended: Bool
    let select: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: select) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
                // ひとことは折り返せば並べられるので、ViewThatFits でなく文字の大きさで分ける
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        summary
                        values(alignment: .leading)
                    }
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        summary
                        Spacer(minLength: 0)
                        values(alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(
                        Color.accentColor, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("goal-setup-proposal-\(proposal.pace.rawValue)")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(GoalSetupDifficultyText.paceName(proposal.pace))
                    .font(.subheadline.weight(.semibold))
                if isRecommended {
                    Text("おすすめ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(.tertiaryLabel), lineWidth: 0.5))
                }
            }
            Text(GoalSetupDifficultyText.difference(proposal.dailyGuideDifferenceKilocalories))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func values(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(WeightAmountText.kilograms(proposal.targetWeightKilograms))
                .font(.subheadline)
            Text(GoalSetupDifficultyText.kilocalories(proposal.dailyGuide.energyKilocalories))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
        .fixedSize()
    }
}
