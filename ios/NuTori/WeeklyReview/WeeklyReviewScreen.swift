import NuToriCore
import SwiftUI

/// 週の振り返り（仕様の「週の振り返り」、`wkform` A の押して進む画面）。上から、週の区切り、一番上のペース、体重、食べた量、
/// P・F・C の1日の平均、日ごと、次の週の1日の目安を並べる。‹ › で週を送り、日ごとの行を押すとタイムラインのその日に戻る
struct WeeklyReviewScreen: View {
    /// 開いたところ。‹ › で送ったときも、同じ開いたところで送る
    let entry: ClientUsageEvent.WeeklyReviewEntry
    /// その週の月曜から、キャッシュの記録で週の振り返りを組む。目標を立てる前の週は nil
    let recap: (CalendarDay) -> WeekRecap?
    let capture: (ClientUsageEvent) async -> Void
    let returnToTimeline: (CalendarDay) -> Void

    init(
        monday: CalendarDay, entry: ClientUsageEvent.WeeklyReviewEntry,
        recap: @escaping (CalendarDay) -> WeekRecap?,
        capture: @escaping (ClientUsageEvent) async -> Void,
        returnToTimeline: @escaping (CalendarDay) -> Void
    ) {
        self.entry = entry
        self.recap = recap
        self.capture = capture
        self.returnToTimeline = returnToTimeline
        _monday = State(initialValue: monday)
    }

    var body: some View {
        Group {
            if let shown = recap(monday) {
                content(shown)
                    // 開いたときと、‹ › で週を送ったときに送る
                    .task(id: monday) {
                        await capture(.weeklyReviewOpened(entry: entry, weeksAgo: shown.weeksAgo))
                    }
            } else {
                // 目標の記録が消えて組めなくなったら（ほかの端末で消して同期で届いた）、タイムラインに戻る
                Color(.systemGroupedBackground)
                    .onAppear { dismiss() }
            }
        }
        .navigationTitle("週の振り返り")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("weekly-review")
    }

    @State private var monday: CalendarDay
    @Environment(\.dismiss) private var dismiss

    private func content(_ shown: WeekRecap) -> some View {
        List {
            Section {
                weekNavigation(shown)
                if let topLine = shown.topLine {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topLine.headline)
                            .font(.headline)
                        Text(topLine.sentence)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("weekly-review-top-line")
                }
            }
            Section("体重") {
                WeekRecapWeightChart(recap: shown)
                if let trendText = shown.weight.trendText {
                    Text(trendText)
                        .monospacedDigit()
                }
                Text(shown.weight.recordText)
                    .monospacedDigit()
            }
            foodSection(shown)
            nutrientSection(shown)
            daysSection(shown)
            if let next = shown.nextWeekGuide {
                Section("次の週の1日の目安") {
                    VStack(alignment: .leading, spacing: 8) {
                        // 大きな文字で横に詰めると、値が単位の途中で折り返すので、横に収まらなければ変わった量を値の下に置く
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline) {
                                nextWeekEnergy(next)
                                Spacer(minLength: 8)
                                nextWeekChange(next)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                nextWeekEnergy(next)
                                nextWeekChange(next)
                            }
                        }
                        .monospacedDigit()
                        Text(next.sentence)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("weekly-review-next-week-guide")
                }
            }
        }
    }

    private func nextWeekEnergy(_ next: WeekRecap.NextWeekGuide) -> some View {
        Text(NutritionText.kilocalories(next.energyKilocalories))
            .font(.title2)
    }

    private func nextWeekChange(_ next: WeekRecap.NextWeekGuide) -> some View {
        Text(next.changeText)
            .foregroundStyle(.secondary)
    }

    /// ‹ 「9月14日〜20日」「減量の3週目」 ›。いちばん新しい週の › は押せない（薄い）
    private func weekNavigation(_ shown: WeekRecap) -> some View {
        HStack {
            Button {
                guard let previous = shown.previousMonday else { return }
                withAnimation { monday = previous }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("前の週")
            .disabled(shown.previousMonday == nil)
            .accessibilityIdentifier("weekly-review-previous-week")
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(shown.title)
                    .font(.headline)
                    .monospacedDigit()
                    .accessibilityIdentifier("weekly-review-title")
                Text(shown.weekLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button {
                guard let next = shown.nextMonday else { return }
                withAnimation { monday = next }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("次の週")
            .disabled(shown.nextMonday == nil)
            .accessibilityIdentifier("weekly-review-next-week")
        }
        // 行の中に2つのボタンを置くので、行そのものを押せるようにしない
        .buttonStyle(.borderless)
    }

    private func foodSection(_ shown: WeekRecap) -> some View {
        Section("食べた量") {
            WeekRecapFoodChart(recap: shown)
            LabeledContent(shown.averageFood?.label ?? "平均") {
                Text(
                    shown.averageFood.map { NutritionText.kilocalories($0.energyKilocalories) }
                        ?? "—")
            }
            .monospacedDigit()
            if let dailyGuide = shown.dailyGuide {
                LabeledContent("1日の目安") {
                    Text(NutritionText.kilocalories(dailyGuide.energyKilocalories))
                }
                .monospacedDigit()
            }
        }
    }

    /// 「P たんぱく質 109 / 110 g」。1日の目安がまだ届いていなければ平均だけ
    private func nutrientSection(_ shown: WeekRecap) -> some View {
        Section {
            ForEach(PFC.allCases, id: \.self) { pfc in
                LabeledContent {
                    Text(nutrientText(pfc, shown: shown))
                        .monospacedDigit()
                } label: {
                    HStack(spacing: 6) {
                        pfc.key
                        Text("\(pfc.letter) \(pfc.name)")
                    }
                }
            }
        } header: {
            Text("P・F・C の1日の平均")
        } footer: {
            Text(
                shown.dailyGuide == nil
                    ? (shown.averageFood?.label ?? "平均")
                    : "\(shown.averageFood?.label ?? "平均") / 1日の目安")
        }
    }

    private func nutrientText(_ pfc: PFC, shown: WeekRecap) -> String {
        let average = shown.averageFood.map { "\(grams(pfc, in: $0))" } ?? "—"
        guard let dailyGuide = shown.dailyGuide else { return "\(average) g" }
        return "\(average) / \(pfc.grams(in: dailyGuide)) g"
    }

    private func grams(_ pfc: PFC, in average: WeekRecap.AverageFood) -> Int {
        switch pfc {
        case .protein: average.proteinGrams
        case .fat: average.fatGrams
        case .carbohydrate: average.carbohydrateGrams
        }
    }

    /// 「9月14日（月） 1,890 kcal 73.4 kg ›」。押すとタイムラインのその日に戻る
    private func daysSection(_ shown: WeekRecap) -> some View {
        Section {
            ForEach(shown.days, id: \.day) { day in
                Button {
                    returnToTimeline(day.day)
                } label: {
                    HStack(spacing: 12) {
                        // 大きな文字で横に詰めると、値が数字の途中で折り返すので、横に収まらなければ値を日付の下に置く
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                Text(TimelineDayText.label(for: day.day))
                                    .foregroundStyle(Color.primary)
                                Spacer(minLength: 0)
                                dayValues(day)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(TimelineDayText.label(for: day.day))
                                    .foregroundStyle(Color.primary)
                                dayValues(day)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .monospacedDigit()
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier(
                    "weekly-review-day-\(TimelineDayText.startedOn(for: day.day))")
            }
        }
    }

    /// 「1,890 kcal 73.4 kg」。横に収まらなければ縦に並べる。ボタンの中の階層の色は押せる色に染まるので、文字の色をじかに指す
    private func dayValues(_ day: WeekRecap.Day) -> some View {
        let food = Text(Self.foodText(day.food))
        let weight = Text(day.weightKilograms.map(WeightAmountText.kilograms) ?? "—")
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                food
                weight
            }
            VStack(alignment: .leading, spacing: 2) {
                food
                weight
            }
        }
        .foregroundStyle(Color(.secondaryLabel))
    }

    /// 食事の無い日は「記録なし」、kcal が出ない日は「—」
    private static func foodText(_ food: DayFood) -> String {
        switch food {
        case .noMeals: "記録なし"
        case .allPending, .unavailable: "—"
        case .figures(let figures):
            NutritionText.amount(figures.totals[.energyKcal], of: .energyKcal)
        }
    }
}
