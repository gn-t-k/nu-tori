import NuToriCore
import SwiftUI

struct DaySummarySheet: View {
    let timeline: Timeline
    let onSeeOnTimeline: (CalendarDay) -> Void

    var body: some View {
        NavigationStack {
            List {
                if shown.food != .noMeals {
                    foodSection(shown.food)
                }
                Section {
                    if let weight = shown.representativeWeight {
                        LabeledContent("この日の体重") {
                            VStack(alignment: .trailing) {
                                Text(WeightAmountText.kilograms(weight.record.kilograms))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                if weight.otherRecordCount > 0 {
                                    Text("ほか\(weight.otherRecordCount)件")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("記録なし")
                    }
                }
                Section {
                    Button("タイムラインでこの日を見る") {
                        onSeeOnTimeline(shownDay)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    dayNavigation
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("day-summary")
    }

    init(
        timeline: Timeline, day: CalendarDay, onSeeOnTimeline: @escaping (CalendarDay) -> Void
    ) {
        self.timeline = timeline
        self.onSeeOnTimeline = onSeeOnTimeline
        _shownDay = State(initialValue: day)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var shownDay: CalendarDay
    /// 丸の中の kcal の大きさに合わせて、丸と輪の太さも大きくする
    @ScaledMetric(relativeTo: .title2) private var ringDiameter: CGFloat = 128
    @ScaledMetric(relativeTo: .title2) private var ringLineWidth: CGFloat = 14

    private var foodLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))
    }

    private var dayNavigation: some View {
        HStack {
            Button {
                guard let previous else { return }
                withAnimation { shownDay = previous }
            } label: {
                Image(systemName: "chevron.left")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("前の日")
            .disabled(previous == nil)

            Text(TimelineDayText.label(for: shownDay))
                .font(.headline)

            Button {
                guard let next else { return }
                withAnimation { shownDay = next }
            } label: {
                Image(systemName: "chevron.right")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("次の日")
            .disabled(next == nil)
        }
    }

    /// 目標が無いあいだは、丸は P・F・C の割合で一周し、食べた量だけを書く。
    /// 大きな文字では、丸を文字に合わせて広げ、丸の下に値を並べる
    private func foodSection(_ food: DayFood) -> some View {
        let ring = DayRingView(
            shares: food.figures?.shares, diameter: ringDiameter, lineWidth: ringLineWidth
        )
        .overlay {
            ringCenter(food.figures)
        }
        let facts = VStack(spacing: 8) {
            ForEach(PFC.allCases, id: \.self) { pfc in
                if pfc != .protein {
                    Divider()
                }
                pfcFact(pfc, figures: food.figures)
            }
        }
        return Section {
            foodLayout {
                ring
                facts
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("day-food")
        } header: {
            Text("食事と栄養")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(food.notes, id: \.self) { note in
                    Text(note)
                }
            }
        }
    }

    /// 丸の中の kcal。推定が済んだ食事の kcal が無ければ「—」
    private func ringCenter(_ figures: DayFood.Figures?) -> some View {
        let kilocalories = figures?.totals[.energyKcal] ?? .unknown
        return VStack(spacing: 0) {
            Text(NutritionText.number(kilocalories, of: .energyKcal))
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(NutritionText.unit(kilocalories, of: .energyKcal))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 名前と値が1行に収まらないときは、値を名前の下に置く。名前と値の途中では改行しない
    private func pfcFact(_ pfc: PFC, figures: DayFood.Figures?) -> some View {
        let name = HStack(alignment: .firstTextBaseline, spacing: 6) {
            pfc.key
            Text("\(pfc.letter) \(pfc.name)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        let amount = Text(
            NutritionText.amount(figures?.totals[pfc.nutrient] ?? .unknown, of: pfc.nutrient)
        )
        .font(.subheadline)
        .fontWeight(.semibold)
        .monospacedDigit()
        .contentTransition(.numericText())
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                name.fixedSize()
                Spacer(minLength: 0)
                amount.fixedSize()
            }
            VStack(alignment: .leading, spacing: 2) {
                name
                amount
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // 見ている日は並べる範囲の中だけ動き、days はその範囲のすべての日を持つ
    private var shown: Timeline.Day {
        let index = timeline.dayRange.lowerBound.distance(to: shownDay)
        return timeline.days[index]
    }

    private var previous: CalendarDay? {
        let day = shownDay.advanced(by: -1)
        return timeline.dayRange.contains(day) ? day : nil
    }

    private var next: CalendarDay? {
        let day = shownDay.advanced(by: 1)
        return timeline.dayRange.contains(day) ? day : nil
    }
}
