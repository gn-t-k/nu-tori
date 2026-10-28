import NuToriCore
import SwiftUI

/// 目標を立てる知らせのカードの、決まったあとの形。「目標を決めました」と、向き・期限・目標体重（維持は「65.0 kg を保つ」）、1日の目安、P・F・C の目安を示す。大変さは保存しないので出さない。
/// 凍結済みのカードの「目標を見る ›」は、目標の画面が次の仕様なので置かない
struct GoalDecidedCard: View {
    /// 今の目標。立て直したあとも、カードは1つのまま今の目標を示す
    let goal: Goal
    /// その目標の1日の目安。まだ届いていなければ nil で、目安の行を出さない
    let dailyGuide: DailyGuide?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("目標を決めました")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(
                    WeightAmountText.clock(ClockTime(containing: goal.decidedAt, in: goal.timeZone))
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Text(
                "\(Text(GoalDirectionText.name(goal.direction)).fontWeight(.semibold))　\(goalLine)"
            )
            .font(.subheadline)
            .monospacedDigit()
            .accessibilityIdentifier("goal-decided-goal")
            if let dailyGuide {
                Text(
                    "1日の目安 \(Text(NutritionText.kilocalories(dailyGuide.energyKilocalories)).fontWeight(.semibold))"
                )
                .font(.subheadline)
                .monospacedDigit()
                .accessibilityIdentifier("goal-decided-daily-guide")
                // 大きな文字では、P・F・C を縦に並べる
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { pfcGuides(dailyGuide) }
                    VStack(alignment: .leading, spacing: 4) { pfcGuides(dailyGuide) }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goal-decided")
    }

    /// 減量・増量は「12月24日（木）までに 70.1 kg」、維持は「65.0 kg を保つ」
    private var goalLine: String {
        let target = WeightAmountText.kilograms(goal.targetWeightKilograms)
        guard let weightChange = goal.direction.weightChange else {
            return "\(target) を保つ"
        }
        return "\(TimelineDayText.label(for: weightChange.deadlineDay))までに \(target)"
    }

    private func pfcGuides(_ dailyGuide: DailyGuide) -> some View {
        ForEach(PFC.allCases, id: \.self) { pfc in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                pfc.key
                Text(
                    "\(pfc.letter) \(NutritionText.amount(.exactly(Double(pfc.grams(in: dailyGuide))), of: pfc.nutrient))"
                )
            }
        }
    }
}
