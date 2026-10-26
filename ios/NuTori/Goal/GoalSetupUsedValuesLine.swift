import NuToriAPI
import NuToriCore
import SwiftUI

/// 目標案の上の1行。逆算できた人と立て直しは「推定消費カロリー　2,250 kcal」の値の行、逆算できない人は使った値と「変える」。
/// 今日の体重の記録が無ければ、使った最後の体重記録の日を添える。値が届くまでは、同じ形の文で場所だけを取る
struct GoalSetupUsedValuesLine: View {
    /// 目標案が届く前は nil
    let usedValues: GoalSetupUsedValues?
    /// 今日の体重の記録が無いときの、使った最後の体重記録の日
    let pastWeightRecordDay: CalendarDay?
    let reviseMissingValues: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let usedValues {
                line(usedValues)
            } else {
                expenditureRow(2250)
                    .hidden()
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func line(_ usedValues: GoalSetupUsedValues) -> some View {
        let weightNote = pastWeightRecordDay.map {
            "体重は \(GoalSetupDayText.monthDay($0))までの記録を使っています。"
        }
        switch usedValues {
        case .formula(let body, let weightKilograms):
            VStack(alignment: .leading, spacing: 2) {
                // 大きな文字では、「変える」に押されて使った値が細い列に折れるので、「変える」を下に置く
                if dynamicTypeSize.isAccessibilitySize {
                    Text(bodyText(body, weightKilograms: weightKilograms))
                    reviseButton
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(bodyText(body, weightKilograms: weightKilograms))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        reviseButton
                    }
                }
                if let weightNote {
                    Text(weightNote)
                }
            }
            .accessibilityIdentifier("goal-setup-used-values")
        case .backCalculated(let kilocalories), .current(let kilocalories):
            // 最近4週の記録から推定したことは、値の行の名前で足りるので文にしない（#754）
            VStack(alignment: .leading, spacing: 8) {
                expenditureRow(kilocalories)
                if let weightNote {
                    Text(weightNote)
                }
            }
            .accessibilityIdentifier("goal-setup-used-values")
        }
    }

    private var reviseButton: some View {
        Button("変える", action: reviseMissingValues)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("goal-setup-revise-missing-values")
    }

    /// 「推定消費カロリー　2,250 kcal」。下の案の差（「−400 kcal」）の起点なので、本文の大きさで置く
    private func expenditureRow(_ kilocalories: Int) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("推定消費カロリー")
                Spacer(minLength: 12)
                Text(NutritionText.kilocalories(kilocalories))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(Color.primary)
            .accessibilityElement(children: .combine)
            Divider()
        }
    }

    /// 「172 cm・35歳・男性・72.4 kg・歩数から」。体重は目標案の計算に使った開始の日の体重の傾向
    private func bodyText(_ body: GoalSetupBody, weightKilograms: Double) -> String {
        let height = NutritionText.quantity(body.heightCentimeters, unit: "cm")
        let sex = GoalSetupBodyText.sex(body.sex)
        let activity =
            switch body.activity {
            case .steps: "歩数から"
            case .level(let level): GoalSetupBodyText.level(level)
            }
        return
            "\(height)・\(body.ageYears)歳・\(sex)・\(WeightAmountText.kilograms(weightKilograms))・\(activity)"
    }
}

extension GoalSetupUsedValuesLine {
    init(content: GoalSetupFlowContent, actions: GoalSetupFlowActions) {
        self.init(
            usedValues: content.usedValues,
            pastWeightRecordDay: content.pastWeightRecordDay,
            reviseMissingValues: actions.reviseMissingValues)
    }
}
