import NuToriCore
import SwiftUI

struct DaySummarySheet: View {
    let timeline: Timeline
    /// 速さの出す条件（記録のある日の数）を数えるための、キャッシュの体重記録（送り待ちを含む）
    let weightRecords: [WeightRecord]
    let weightTrend: WeightTrend?
    /// 今日を含む目標の、進行中の要約。目標が無ければ nil。今日の日のまとめにだけ出す
    let goalProgress: GoalProgress?
    let today: CalendarDay
    /// 目標が無いときの「目標を立てる」。シートを閉じ、タイムラインの知らせのカードまで送って広げる。目標があれば nil
    let startGoalSetup: (() -> Void)?
    let onSeeOnTimeline: (CalendarDay) -> Void

    var body: some View {
        NavigationStack {
            List {
                if shown.food != .noMeals {
                    foodSection(shown)
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
                    if let speed = WeightTrendSpeed(
                        on: shownDay, trend: weightTrend, weightRecords: weightRecords)
                    {
                        LabeledContent("体重の傾向") {
                            Text(speed.text)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    // 押しても開くものは無い（目標の画面は次の仕様）
                    if shownDay == today, let goalProgress {
                        LabeledContent("目標") {
                            Text(goalProgress.text)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .accessibilityIdentifier("day-summary-goal-progress")
                    }
                    // 目標が無いことを文で書かず、立てる入口を置く
                    if let startGoalSetup {
                        Button("目標を立てる", action: startGoalSetup)
                            .accessibilityIdentifier("day-summary-start-goal-setup")
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
        timeline: Timeline, day: CalendarDay, weightRecords: [WeightRecord],
        weightTrend: WeightTrend?, goalProgress: GoalProgress?, today: CalendarDay,
        startGoalSetup: (() -> Void)?,
        onSeeOnTimeline: @escaping (CalendarDay) -> Void
    ) {
        self.timeline = timeline
        self.weightRecords = weightRecords
        self.weightTrend = weightTrend
        self.goalProgress = goalProgress
        self.today = today
        self.startGoalSetup = startGoalSetup
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

    /// 1日の目安と比べる日は、丸は一周を目安にして食べた分だけ進み、P・F・C を「食べた量 / 目安」にし、目安の kcal を添える。
    /// 比べない日（目標を立てる前の日）は、丸は P・F・C の割合で一周し、食べた量だけを書く。丸の中はどちらも食べた kcal。
    /// 大きな文字では、丸を文字に合わせて広げ、丸の下に値を並べる
    private func foodSection(_ day: Timeline.Day) -> some View {
        let food = day.food
        let dailyGuide = day.dailyGuide
        let dayRing = day.ring
        let ring = DayRingView(
            arcs: dayRing.arcs, exceedsDailyGuide: dayRing.exceedsDailyGuide,
            diameter: ringDiameter, lineWidth: ringLineWidth,
            background: Color(.secondarySystemGroupedBackground)
        )
        .overlay {
            ringCenter(food.figures)
        }
        // 名前と値の途中で改行させないため、1行でも横に収まらなければ3行とも値を名前の下に置く。行ごとに決めると、値の位置が行によってずれる
        let facts = ViewThatFits(in: .horizontal) {
            pfcFacts(figures: food.figures, dailyGuide: dailyGuide, layout: .valueBesideName)
            pfcFacts(figures: food.figures, dailyGuide: dailyGuide, layout: .valueBelowName)
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
                // 試作（prototype-goal-setup-look の「決まったあと」）のとおり、まとまりの下の1行目に置く
                if let dailyGuide {
                    Text(
                        "1日の目安 \(NutritionText.kilocalories(dailyGuide.energyKilocalories))"
                    )
                    .monospacedDigit()
                    .accessibilityIdentifier("day-summary-daily-guide")
                }
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

    private enum PFCFactLayout {
        case valueBesideName
        case valueBelowName
    }

    private func pfcFacts(figures: DayFood.Figures?, dailyGuide: DailyGuide?, layout: PFCFactLayout)
        -> some View
    {
        VStack(spacing: 8) {
            ForEach(PFC.allCases, id: \.self) { pfc in
                if pfc != .protein {
                    Divider()
                }
                pfcFact(pfc, figures: figures, dailyGuide: dailyGuide, layout: layout)
            }
        }
    }

    @ViewBuilder
    private func pfcFact(
        _ pfc: PFC, figures: DayFood.Figures?, dailyGuide: DailyGuide?, layout: PFCFactLayout
    ) -> some View {
        let name = HStack(alignment: .firstTextBaseline, spacing: 6) {
            pfc.key
            Text("\(pfc.letter) \(pfc.name)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        let eaten = figures?.totals[pfc.nutrient] ?? .unknown
        let amount = Text(
            dailyGuide.map {
                NutritionText.amount(eaten, of: pfc.nutrient, guide: pfc.grams(in: $0))
            } ?? NutritionText.amount(eaten, of: pfc.nutrient)
        )
        .font(.subheadline)
        .fontWeight(.semibold)
        .monospacedDigit()
        .contentTransition(.numericText())
        switch layout {
        case .valueBesideName:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                name.fixedSize()
                Spacer(minLength: 0)
                amount.fixedSize()
            }
        case .valueBelowName:
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
