import NuToriCore
import SwiftUI

/// 1日の目安の変更の知らせ（仕様の `change` D）。振り返りのカードのすぐ下に置き、答えを持たない。
/// 見出しと時刻、大きく新しい値と変わった量、P・F・C、理由の文、まとめて見直したときの1行、右下に「目標 ›」
struct DailyGuideChangeNoticeCard: View {
    let notice: DailyGuideChangeNotice
    /// 「目標 ›」。目標の画面を開く
    let openGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("1日の目安が変わりました")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(
                    WeightAmountText.clock(
                        ClockTime(containing: notice.review.reviewedAt, in: notice.review.timeZone))
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 6) {
                // 大きな文字で1つの文につなげると、変わった量が「−」の後ろで折り返すので、横に収まらなければ値の下に置く
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        energyText
                        changeText
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        energyText
                        changeText
                    }
                }
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "新しい1日の目安 \(NutritionText.kilocalories(notice.dailyGuide.energyKilocalories))、\(notice.changeText)"
                )
                .accessibilityIdentifier("daily-guide-change-value")
                // 大きな文字では、P・F・C を縦に並べる（目標を決めたカードと同じ）
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { pfcGuides }
                    VStack(alignment: .leading, spacing: 4) { pfcGuides }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(notice.reasonText)
                if let batchText = notice.batchText {
                    Text(batchText)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
            Button(action: openGoal) {
                HStack(spacing: 4) {
                    Text("目標")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            // 押せる高さは 44 のまま、見た目は理由の文のすぐ下に寄せる（試作の「目標 ›」の高さ）。カードの下の余白に押せる範囲をはみ出させる
            .padding(.vertical, -10)
            .accessibilityLabel("目標")
            .accessibilityIdentifier("daily-guide-change-open-goal")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-guide-change-notice")
    }

    /// 大きく新しい値「1,850 kcal」
    private var energyText: some View {
        Text(NutritionText.kilocalories(notice.dailyGuide.energyKilocalories))
            .font(.title2)
    }

    /// 変わった量「−30 kcal」
    private var changeText: some View {
        Text(notice.changeText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var pfcGuides: some View {
        ForEach(PFC.allCases, id: \.self) { pfc in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                pfc.key
                Text(
                    "\(pfc.letter) \(NutritionText.amount(.exactly(Double(pfc.grams(in: notice.dailyGuide))), of: pfc.nutrient))"
                )
            }
        }
    }
}
