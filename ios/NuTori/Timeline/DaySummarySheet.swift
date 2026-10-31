import NuToriCore
import SwiftUI

struct DaySummarySheet: View {
    let timeline: Timeline
    /// 速さの出す条件（記録のある日の数）を数えるための、キャッシュの体重記録（送り待ちを含む）
    let weightRecords: [WeightRecord]
    let weightTrend: WeightTrend?
    /// 目標の行と週の振り返りの行を、見ている日を含む目標で組むもとの記録
    let goalRecords: GoalRecords
    let today: CalendarDay
    /// 目標が無いときの「目標を立てる」。シートを閉じ、タイムラインの知らせのカードまで送って広げる。目標があれば nil
    let startGoalSetup: (() -> Void)?
    /// 週の振り返りの行に書く週（「9月21日〜27日（途中）」）。その週を含む目標が無ければ nil で、行を出さない
    let weekRecapTitle: (CalendarDay) -> String?
    /// シートを閉じ、その日の体重の画面をタイムラインの上に押して進む
    let openWeightScreen: (CalendarDay) -> Void
    /// シートを閉じ、タイムラインの上に押して進む
    let openGoalScreen: () -> Void
    /// 見ている日を含む週を開く。シートを閉じ、タイムラインの上に押して進む
    let openWeeklyReview: (CalendarDay) -> Void
    /// シートを閉じ、タイムラインの一番下に目標の設定のカードを出して広げる
    let openNextGoal: (DaySummaryGoal.NextGoal) -> Void
    let onSeeOnTimeline: (CalendarDay) -> Void

    var body: some View {
        NavigationStack {
            List {
                if shown.food != .noMeals {
                    foodSection(shown)
                }
                Section {
                    weightRow(shown.representativeWeight)
                    if let speed = WeightTrendSpeed(
                        on: shownDay, trend: weightTrend, weightRecords: weightRecords)
                    {
                        LabeledContent("体重の傾向") {
                            Text(speed.text)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    if let goal = DaySummaryGoal(
                        day: shownDay, today: today, records: goalRecords)
                    {
                        goalRows(goal)
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
        weightTrend: WeightTrend?, goalRecords: GoalRecords, today: CalendarDay,
        startGoalSetup: (() -> Void)?,
        weekRecapTitle: @escaping (CalendarDay) -> String?,
        openWeightScreen: @escaping (CalendarDay) -> Void,
        openGoalScreen: @escaping () -> Void,
        openWeeklyReview: @escaping (CalendarDay) -> Void,
        openNextGoal: @escaping (DaySummaryGoal.NextGoal) -> Void,
        onSeeOnTimeline: @escaping (CalendarDay) -> Void
    ) {
        self.timeline = timeline
        self.weightRecords = weightRecords
        self.weightTrend = weightTrend
        self.goalRecords = goalRecords
        self.today = today
        self.startGoalSetup = startGoalSetup
        self.weekRecapTitle = weekRecapTitle
        self.openWeightScreen = openWeightScreen
        self.openGoalScreen = openGoalScreen
        self.openWeeklyReview = openWeeklyReview
        self.openNextGoal = openNextGoal
        self.onSeeOnTimeline = onSeeOnTimeline
        _shownDay = State(initialValue: day)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var shownDay: CalendarDay
    /// 丸の中の kcal の大きさに合わせて、丸と輪の太さも大きくする
    @ScaledMetric(relativeTo: .title2) private var ringDiameter: CGFloat = 128
    @ScaledMetric(relativeTo: .title2) private var ringLineWidth: CGFloat = 14

    /// 「体重　72.4 kg ›」。記録の無い日も、その日の体重の画面へ潜れる
    private func weightRow(_ weight: RepresentativeWeight?) -> some View {
        Button {
            openWeightScreen(shownDay)
        } label: {
            disclosureRow {
                LabeledContent("体重") {
                    if let weight {
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
                    } else {
                        Text("記録なし")
                    }
                }
                .foregroundStyle(Color.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("day-summary-weight")
    }

    /// 体重と同じまとまりに、目標の行（下に小さな文）、達成・期限・期限後の維持の紫の行、週の振り返りの行を足す
    @ViewBuilder private func goalRows(_ goal: DaySummaryGoal) -> some View {
        Button(action: openGoalScreen) {
            disclosureRow(title: "目標", detail: goal.detail)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("day-summary-goal")
        if let nextGoal = goal.nextGoal {
            Button(nextGoal.title) {
                openNextGoal(nextGoal)
            }
            .accessibilityIdentifier("day-summary-next-goal")
        }
        if let weekTitle = weekRecapTitle(shownDay) {
            Button {
                openWeeklyReview(shownDay)
            } label: {
                disclosureRow(title: "週の振り返り", detail: weekTitle)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("day-summary-weekly-review")
        }
    }

    /// 名前の下に小さな文を書き、右端に「›」を置く行
    private func disclosureRow(title: String, detail: String?) -> some View {
        disclosureRow {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(Color.primary)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// 中身の右端に「›」を置く、押して潜る行
    private func disclosureRow(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 12) {
            content()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

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

    /// 1日の目安と比べる日は、丸は一周を目安にして食べた分だけ進み、丸の中に残り（超えた日は超過）、丸の下に「食べた量 / 目安」を書き、P・F・C の行に「食べた量 / 目安」と右端を目安にしたバーを置く。
    /// 比べない日（目標を立てる前の日）は、丸は P・F・C の割合で一周し、丸の中に食べた kcal、P・F・C に食べた量だけを書く。
    /// 大きな文字では、丸を文字に合わせて広げ、丸の下に値を並べる
    private func foodSection(_ day: Timeline.Day) -> some View {
        let food = day.food
        let dailyGuide = day.dailyGuide
        let dayRing = day.ring
        let eatenKilocalories = food.figures?.totals[.energyKcal] ?? .unknown
        let ring = DayRingView(
            arcs: dayRing.arcs, exceedsDailyGuide: dayRing.exceedsDailyGuide,
            diameter: ringDiameter, lineWidth: ringLineWidth,
            background: Color(.secondarySystemGroupedBackground)
        )
        .overlay {
            if let dailyGuide {
                remainderCenter(
                    EatenAgainstGuide(
                        eaten: eatenKilocalories, guide: dailyGuide.energyKilocalories,
                        of: .energyKcal))
            } else {
                eatenCenter(eatenKilocalories)
            }
        }
        // 名前と値の途中で改行させないため、1行でも横に収まらなければ3行とも値を名前の下に置く。行ごとに決めると、値の位置が行によってずれる
        let facts = ViewThatFits(in: .horizontal) {
            pfcFacts(figures: food.figures, dailyGuide: dailyGuide, layout: .valueBesideName)
            pfcFacts(figures: food.figures, dailyGuide: dailyGuide, layout: .valueBelowName)
        }
        return Section {
            foodLayout {
                VStack(spacing: 8) {
                    ring
                    if let dailyGuide {
                        Text(
                            NutritionText.amount(
                                eatenKilocalories, of: .energyKcal,
                                guide: dailyGuide.energyKilocalories)
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    }
                }
                facts
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("day-food")
        } footer: {
            if !food.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(food.notes, id: \.self) { note in
                        Text(note)
                    }
                }
            }
        }
    }

    /// 比べない日の丸の中。食べた kcal で、推定が済んだ食事の kcal が無ければ「—」
    private func eatenCenter(_ kilocalories: NutrientAmount) -> some View {
        VStack(spacing: 0) {
            ringCenterNumber(NutritionText.number(kilocalories, of: .energyKcal))
            ringCenterCaption(NutritionText.unit(kilocalories, of: .energyKcal))
        }
    }

    /// 1日の目安と比べる日の丸の中。上から「あと / 1,199 / kcal」、超えた日は「超過 / 120 / kcal」
    private func remainderCenter(_ againstGuide: EatenAgainstGuide) -> some View {
        let remainder = againstGuide.remainder
        return VStack(spacing: 0) {
            if let lead = remainder.lead {
                ringCenterCaption(lead)
            }
            ringCenterNumber(remainder.number)
            ringCenterCaption(remainder.unit)
        }
    }

    private func ringCenterNumber(_ number: String) -> some View {
        Text(number)
            .font(.title2)
            .fontWeight(.semibold)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private func ringCenterCaption(_ caption: String) -> some View {
        Text(caption)
            .font(.caption)
            .foregroundStyle(.secondary)
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
                pfcFact(pfc, figures: figures, dailyGuide: dailyGuide, layout: layout)
            }
        }
    }

    /// 目安と比べる日は「33 / 90 g」とバーを置き、「あと N g」は書かない（3行並ぶとうるさいため）。
    /// 目安を超えた行は、バーを右端まで満たし、数を太字にする（色では分けない）
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
        let againstGuide = dailyGuide.map {
            EatenAgainstGuide(eaten: eaten, guide: pfc.grams(in: $0), of: pfc.nutrient)
        }
        let amount = Text(
            dailyGuide.map {
                NutritionText.amount(eaten, of: pfc.nutrient, guide: pfc.grams(in: $0))
            } ?? NutritionText.amount(eaten, of: pfc.nutrient)
        )
        .font(.subheadline)
        .fontWeight(againstGuide.map { $0.exceedsGuide ? .bold : .regular } ?? .semibold)
        .monospacedDigit()
        .contentTransition(.numericText())
        VStack(alignment: .leading, spacing: 4) {
            switch layout {
            case .valueBesideName:
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    name.fixedSize()
                    Spacer(minLength: 0)
                    amount.fixedSize()
                }
            case .valueBelowName:
                name
                amount
            }
            if let againstGuide {
                guideBar(againstGuide, color: pfc.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 右端を目安にした細いバー。超えた分は描かない（数の太字で示す）
    private func guideBar(_ againstGuide: EatenAgainstGuide, color: Color) -> some View {
        Capsule()
            .fill(Color(.systemGray5))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * againstGuide.filledFraction)
                }
            }
            .accessibilityHidden(true)
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
