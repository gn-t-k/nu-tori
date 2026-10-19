import NuToriCore
import SwiftUI

/// 目標の画面（仕様の「目標の画面」、`gform` A の押して進む画面）。上から、今の目標のカード、今の1日の目安、体重の傾向、
/// 推定消費カロリーと1日の目安、週の振り返りへの1行、過去の目標を並べる。
/// 「目標を切り替える」とカードのボタンでは、カードをその場で目標の設定のカードに変える（`gswitch` A）
struct GoalScreen: View {
    /// キャッシュの記録から組んだ中身。目標がなければ nil
    let overview: GoalOverview?
    let entry: ClientUsageEvent.GoalScreenEntry
    /// 目標の設定の流れの形。広げているあいだは、今の目標のカードの代わりに描く
    let goalSetupFlow: GoalSetupNoticeCard.Flow
    let timeZone: () -> TimeZone
    /// 週の振り返りへの1行に書く週（「9月14日〜20日」）。その週を組めなければ nil
    let recapTitle: (CalendarDay) -> String?
    let capture: (ClientUsageEvent) async -> Void
    /// 目標の設定の流れを広げる。途中まで進めていれば同じページから
    let openGoalSetup: (GoalSetupObservation.Entry) -> Void
    /// 週の振り返りを、この画面の上に押して進む
    let openWeeklyReview: (CalendarDay) -> Void

    var body: some View {
        Group {
            if let overview {
                content(overview)
            } else {
                // 目標の記録が消えて組めなくなったら（ほかの端末で消して同期で届いた）、タイムラインに戻る
                Color(.systemGroupedBackground)
                    .onAppear { dismiss() }
            }
        }
        .navigationTitle("目標")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        // 週の振り返りから戻ったときは送らない。開いたときの1回だけ
        .task {
            guard !hasCapturedOpening, let overview,
                let status = ClientUsageEvent.GoalScreenStatus(overview.status)
            else { return }
            hasCapturedOpening = true
            await capture(.goalScreenOpened(entry: entry, status: status))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal-screen")
    }

    @State private var hasCapturedOpening = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func content(_ overview: GoalOverview) -> some View {
        ScrollView {
            // DESIGN.md の card-gap（12）。カードの間は VStack の間隔で空ける
            VStack(alignment: .leading, spacing: 12) {
                currentGoal(overview)
                if let dailyGuide = overview.currentDailyGuide {
                    dailyGuideCard(dailyGuide, since: overview.currentDailyGuideSince)
                }
                if let goal = overview.status.goal {
                    GoalScreenCard(title: overview.weightChart.title) {
                        GoalWeightChartView(chart: overview.weightChart, goal: goal)
                    }
                    .accessibilityIdentifier("goal-weight-chart")
                }
                if let energyChart = overview.energyChart {
                    GoalScreenCard(title: "推定消費カロリーと1日の目安") {
                        GoalEnergyChartView(chart: energyChart)
                    }
                    .accessibilityIdentifier("goal-energy-chart")
                }
                if let recapTitle = recapTitle(overview.recapWeekMonday) {
                    weeklyReviewRow(recapTitle, monday: overview.recapWeekMonday)
                }
                if !overview.pastGoals.isEmpty {
                    pastGoals(overview.pastGoals)
                }
            }
            .padding()
            .animation(reduceMotion ? nil : .default, value: goalSetupFlow.expandedPage)
        }
    }

    /// 今の目標のカード。目標の設定の流れを広げているあいだは、その場で目標の設定のカードに変え、今の目標が続くことを添える
    @ViewBuilder private func currentGoal(_ overview: GoalOverview) -> some View {
        if case .expanded(let content, let actions) = goalSetupFlow {
            VStack(alignment: .leading, spacing: 8) {
                GoalSetupFlowCard(content: content, actions: actions, timeZone: timeZone)
                Text(overview.card.continuingNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .accessibilityIdentifier("goal-switch-continuing-note")
            }
            .transition(.opacity)
        } else {
            GoalOverviewCardView(card: overview.card) { action in
                openGoalSetup(Self.setupEntry(of: action))
            }
            .transition(.opacity)
        }
    }

    /// カードのボタンから開いたところ
    private static func setupEntry(of action: GoalOverview.Card.Action)
        -> GoalSetupObservation.Entry
    {
        switch action {
        case .switchGoal: .switchGoal
        case .chooseNextGoal: .chooseNextGoal
        case .setNextGoal: .setNextGoal
        }
    }

    /// 「今の1日の目安」「9月21日から」、「1,850 kcal」と P・F・C
    private func dailyGuideCard(_ dailyGuide: DailyGuide, since: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 大きな文字で横に詰めると、日付の途中で折り返すので、横に収まらなければ日付を見出しの下に置く
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    dailyGuideHeading
                    Spacer(minLength: 8)
                    dailyGuideSince(since)
                }
                VStack(alignment: .leading, spacing: 2) {
                    dailyGuideHeading
                    dailyGuideSince(since)
                }
            }
            Text(NutritionText.kilocalories(dailyGuide.energyKilocalories))
                .font(.title2)
                .monospacedDigit()
            // 大きな文字では、P・F・C を縦に並べる（変更の知らせと同じ）
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { pfcGuides(dailyGuide) }
                VStack(alignment: .leading, spacing: 4) { pfcGuides(dailyGuide) }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goal-daily-guide")
    }

    private var dailyGuideHeading: some View {
        Text("今の1日の目安")
            .font(.headline)
    }

    /// 「9月21日から」
    @ViewBuilder private func dailyGuideSince(_ since: String?) -> some View {
        if let since {
            Text(since)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var weeklyReviewName: some View {
        Text("週の振り返り")
            .foregroundStyle(Color.primary)
    }

    /// 「9月14日〜20日」
    private func weeklyReviewTitle(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(Color(.secondaryLabel))
            .monospacedDigit()
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

    /// 「週の振り返り 9月14日〜20日 ›」。押すとその週の週の振り返りを開く
    private func weeklyReviewRow(_ title: String, monday: CalendarDay) -> some View {
        Button {
            openWeeklyReview(monday)
        } label: {
            HStack(spacing: 12) {
                // 大きな文字で横に詰めると、週の日付の途中で折り返すので、横に収まらなければ日付を名前の下に置く
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        weeklyReviewName
                        Spacer(minLength: 0)
                        weeklyReviewTitle(title)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        weeklyReviewName
                        weeklyReviewTitle(title)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal)
            .frame(minHeight: 44)
            .background(
                Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("goal-weekly-review")
    }

    /// 「減量 9月1日〜11月30日」「74.0 → 70.4 kg」、右に「−3.6 kg」。新しい順。潜らない
    private func pastGoals(_ goals: [GoalOverview.PastGoal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("過去の目標")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            VStack(spacing: 0) {
                ForEach(Array(goals.enumerated()), id: \.element.goal.id) { index, past in
                    if index > 0 {
                        Divider()
                            .padding(.leading)
                    }
                    // 大きな文字で横に詰めると、期間が日付の途中で折り返すので、横に収まらなければ結果を期間の下に置く
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            pastGoalPeriod(past)
                            Spacer(minLength: 0)
                            pastGoalResult(past)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            pastGoalPeriod(past)
                            pastGoalResult(past)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .monospacedDigit()
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("goal-past-goal")
                }
            }
            .background(
                Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }

    /// 「減量 9月1日〜11月30日」「74.0 → 70.4 kg」
    private func pastGoalPeriod(_ past: GoalOverview.PastGoal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(past.summary)
            if let weights = past.weightsText {
                Text(weights)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 「−3.6 kg」
    @ViewBuilder private func pastGoalResult(_ past: GoalOverview.PastGoal) -> some View {
        if let result = past.resultText {
            Text(result)
                .foregroundStyle(.secondary)
        }
    }
}

extension GoalStatus {
    /// 今の目標。目標がなければ nil
    fileprivate var goal: Goal? {
        switch self {
        case .noGoal: nil
        case .inProgress(let goal), .achievedBeforeDeadline(let goal), .deadlineReached(let goal),
            .maintainingAfterDeadline(let goal, _):
            goal
        }
    }
}

/// 目標の画面の、見出しの付いた白いカード（グラフを載せる）
private struct GoalScreenCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
    }
}
