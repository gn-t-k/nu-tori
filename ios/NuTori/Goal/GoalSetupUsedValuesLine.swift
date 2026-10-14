import NuToriAPI
import NuToriCore
import SwiftUI

/// 目標案の上の1行。逆算できた人は推定消費カロリー、逆算できない人は使った値と「変える」、立て直しは今の推定消費カロリー。
/// 今日の体重の記録が無ければ、使った最後の体重記録の日を添える。値が届くまでは、同じ形の文で場所だけを取る
struct GoalSetupUsedValuesLine: View {
    let proposals: GoalProposals?
    /// 足りない値の「次へ」で決めた身体データ。逆算できる人は nil
    let submittedBody: GoalSetupBody?
    /// 今日の体重の記録が無いときの、使った最後の体重記録の日
    let pastWeightRecordDay: CalendarDay?
    let reviseMissingValues: () -> Void

    var body: some View {
        Group {
            if let proposals {
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
        let weightNote = pastWeightRecordDay.map {
            "体重は \(GoalSetupDayText.monthDay($0))までの記録を使っています。"
        }
        if proposals.expenditureSource == .formula, let submittedBody {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(
                        bodyText(
                            submittedBody, weightKilograms: proposals.startingWeightTrendKilograms)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("変える", action: reviseMissingValues)
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

extension GoalSetupUsedValuesLine {
    init(content: GoalSetupFlowContent, actions: GoalSetupFlowActions) {
        self.init(
            proposals: content.proposals, submittedBody: content.submittedBody,
            pastWeightRecordDay: content.pastWeightRecordDay,
            reviseMissingValues: actions.reviseMissingValues)
    }
}
