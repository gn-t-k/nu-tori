import NuToriCore
import SwiftUI

/// タイムラインの週の振り返りのカード（仕様の `tlcard` C）。見出し・週の日付・「›」、その週の小さな1日の丸7つ、ペースの1行、見送った週の1行、まとめて見直したときの1行を、上から並べる。押すとその週の週の振り返りを開く
struct WeeklyReviewCardView: View {
    let card: WeeklyReviewCard
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // 大きな文字では、見出しと日付を1つの文として折り返す
                    Text(
                        "\(Text("週の振り返り").fontWeight(.semibold))　\(Text(card.daysText).foregroundStyle(.secondary))"
                    )
                    .font(.subheadline)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 0) {
                    ForEach(card.rings, id: \.day) { slot in
                        miniRing(slot)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines, id: \.self) { line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
            .background(
                Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("週の振り返り、\(card.daysText)")
        // 7日の丸を、曜日ごとに読む。帯の丸と同じ書き方にする
        .accessibilityValue((card.rings.map(ringDescription) + lines).joined(separator: "。"))
        .accessibilityHint("この週の振り返りを開きます")
        .accessibilityIdentifier("weekly-review-card")
    }

    /// ペースの1行、見送った週の1行、まとめて見直したときの1行
    private var lines: [String] {
        [card.paceText, card.deferralText, card.batchText].compactMap(\.self)
    }

    private func miniRing(_ slot: RingStrip.Slot) -> some View {
        let diameter: CGFloat = 22
        return VStack(spacing: 4) {
            switch slot {
            case .beforeFirstDay:
                // 使い始める前の日は丸を描かない（帯と同じ）
                Color.clear.frame(width: diameter, height: diameter)
            case .ring(_, let dayRing):
                DayRingView(
                    arcs: dayRing.arcs, exceedsDailyGuide: dayRing.exceedsDailyGuide,
                    diameter: diameter, lineWidth: 3.5,
                    background: Color(.secondarySystemGroupedBackground)
                )
                .overlay {
                    // 体重を記録した日は、丸の中に灰色の点を付ける（帯と同じ）
                    if dayRing.hasWeightRecord {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            Text(TimelineDayText.weekdaySymbol(for: slot.day))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func ringDescription(_ slot: RingStrip.Slot) -> String {
        let label = TimelineDayText.label(for: slot.day)
        switch slot {
        case .beforeFirstDay:
            return "\(label)、使い始める前"
        case .ring(_, let dayRing):
            return
                ([label, dayRing.hasWeightRecord ? "体重の記録あり" : "体重の記録なし"]
                + [
                    dayRing.hasRecordedFood ? "食事の記録あり" : "食事の記録なし",
                    dayRing.exceedsDailyGuide ? "1日の目安を超えた" : nil,
                ].compactMap(\.self)).joined(separator: "、")
        }
    }
}
