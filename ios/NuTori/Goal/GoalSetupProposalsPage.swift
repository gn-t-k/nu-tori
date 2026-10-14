import NuToriAPI
import NuToriCore
import SwiftUI

/// 目標案のページ。見出し「12月24日までの目標を選んでください」と、ゆるめ・標準・ハードの3つの「選ぶ」行。
/// 「おすすめ」は標準に付け、出せない案は押せない灰色の枠に理由を書く。選んでから「この目標で始める」で決まる。
/// 案が届くまでは、届く場所の高さを先に取り、その中央に回る印を出す（届いても「戻る」「閉じる」が動かない）
struct GoalSetupProposalsPage: View {
    let flow: GoalSetupFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GoalSetupUsedValuesLine(flow: flow)
            Text("\(GoalSetupDayText.monthDay(flow.deadline))までの目標を選んでください")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal-setup-proposals-heading")
            Group {
                if case .weightChange(let weightChange)? = flow.proposals?.plan {
                    rows(weightChange)
                } else {
                    waitingRows
                }
            }
            .opacity(isDeciding ? 0.4 : 1)
            .disabled(isDeciding)
            if flow.showsRecalculated {
                Text("新しい体重で計算し直しました。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if flow.unreachableRequest == .decision {
                Text(GoalSetupUnreachableText.decision)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("goal-setup-unreachable")
            }
            GoalSetupStartButton(
                flow: flow, title: "この目標で始める", identifier: "goal-setup-proposal-start"
            )
            .disabled(flow.proposals == nil)
            GoalSetupFooter(flow: flow) {
                if flow.unreachableRequest == .decision {
                    GoalSetupRetryButton(flow: flow)
                } else {
                    Button("目標体重を自分で決める") {
                        flow.openCustomTargetWeight()
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("goal-setup-open-custom")
                    // 届くまでは場所だけを取り、届いてもページの下の行を動かさない
                    .opacity(flow.proposals == nil ? 0 : 1)
                    .disabled(flow.proposals == nil)
                }
            }
            .opacity(isDeciding ? 0.4 : 1)
            .disabled(isDeciding)
        }
    }

    private var isDeciding: Bool {
        flow.decision != .idle
    }

    private func rows(_ weightChange: GoalProposals.WeightChange) -> some View {
        VStack(spacing: 8) {
            ForEach(weightChange.proposals, id: \.pace) { proposal in
                switch proposal.availability {
                case .offered(let offered):
                    GoalProposalRow(
                        proposal: offered,
                        isSelected: offered.pace == flow.selectedPace,
                        isRecommended: offered.pace == .standard
                    ) {
                        flow.selectPace(offered.pace)
                    }
                case .unavailable(let reason):
                    unavailableRow(pace: proposal.pace, reason: reason)
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

/// 目標案の上の1行。逆算できた人は推定消費カロリー、逆算できない人は使った値と「変える」、立て直しは今の推定消費カロリー。
/// 今日の体重の記録が無ければ、使った最後の体重記録の日を添える。値が届くまでは、同じ形の文で場所だけを取る
struct GoalSetupUsedValuesLine: View {
    let flow: GoalSetupFlow

    var body: some View {
        Group {
            if let proposals = flow.proposals {
                line(proposals)
            } else {
                Text(expenditureText(source: .backCalculated, kilocalories: 2250))
                    .hidden()
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func line(_ proposals: GoalProposals) -> some View {
        let weightNote = flow.pastWeightRecordDay.map {
            "体重は \(GoalSetupDayText.monthDay($0))までの記録を使っています。"
        }
        if proposals.expenditureSource == .formula, let body = flow.usedBody {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(bodyText(body, weightKilograms: proposals.startingWeightTrendKilograms))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("変える") {
                        flow.reviseMissingValues()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("goal-setup-revise-missing-values")
                }
                if let weightNote {
                    Text(weightNote)
                }
            }
            .accessibilityIdentifier("goal-setup-used-values")
        } else {
            Text(
                [
                    expenditureText(
                        source: proposals.expenditureSource,
                        kilocalories: proposals.expenditureKilocalories),
                    weightNote,
                ].compactMap(\.self).joined()
            )
            .accessibilityIdentifier("goal-setup-used-values")
        }
    }

    private func expenditureText(source: GoalProposals.ExpenditureSource, kilocalories: Int)
        -> String
    {
        let amount = GoalSetupDifficultyText.kilocalories(kilocalories)
        return switch source {
        case .current: "今の推定消費カロリーは、1日に \(amount) です。"
        case .backCalculated, .formula: "最近4週の記録から推定した消費カロリーは、1日に \(amount) です。"
        }
    }

    /// 「172 cm・35歳・男性・72.4 kg・歩数から」。体重は目標案の計算に使った開始の日の体重の傾向
    private func bodyText(_ body: GoalSetupBody, weightKilograms: Double) -> String {
        let height = NutritionText.quantity(body.heightCentimeters, unit: "cm")
        let sex =
            switch body.sex {
            case .male: "男性"
            case .female: "女性"
            }
        let activity =
            switch body.activity {
            case .steps: "歩数から"
            case .level(.sedentary): "ほぼ座り仕事"
            case .level(.standing): "立ち仕事が多い"
            case .level(.active): "よく動く"
            }
        return
            "\(height)・\(body.ageYears)歳・\(sex)・\(WeightAmountText.kilograms(weightKilograms))・\(activity)"
    }
}

/// 「この目標で始める」「維持で始める」。押すと、ボタンの中に回る印を文字と並べて出す（DESIGN.md の「待っている表示」）
struct GoalSetupStartButton: View {
    let flow: GoalSetupFlow
    let title: String
    let identifier: String

    var body: some View {
        Button {
            Task { await flow.decide() }
        } label: {
            HStack(spacing: 8) {
                if flow.decision != .idle {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
    }
}

/// 案の名前と、大変さのひとこと
enum GoalSetupDifficultyText {
    static func paceName(_ pace: GoalProposals.Pace) -> String {
        switch pace {
        case .gentle: "ゆるめ"
        case .standard: "標準"
        case .hard: "ハード"
        }
    }

    /// 1日の目安と推定消費カロリーの差から「推定消費カロリーより 400 kcal 少ない」（増量は「多い」）
    static func difference(_ kilocalories: Int) -> String {
        guard kilocalories != 0 else { return "推定消費カロリーと同じ" }
        let side = kilocalories < 0 ? "少ない" : "多い"
        return "推定消費カロリーより \(Self.kilocalories(abs(kilocalories))) \(side)"
    }

    /// 「2,250 kcal」
    static func kilocalories(_ kilocalories: Int) -> String {
        NutritionText.amount(.exactly(Double(kilocalories)), of: .energyKcal)
    }
}

/// 期限の見出しと添え書きの日付。「12月24日」
enum GoalSetupDayText {
    static func monthDay(_ day: CalendarDay) -> String {
        "\(day.month)月\(day.day)日"
    }
}
