import NuToriAPI
import NuToriCore
import SwiftUI

/// 目標を立てる知らせのカードを広げた形。1ページに1つの問いで、ページを送って進む（`06-layout.md`「目標の設定の流れ」の「カードの振る舞い」）。
/// カードの中はスクロールさせず、タイムラインごと送る。「閉じる」はどのページでも右上、「戻る」は2ページ目から左下に置く
struct GoalSetupFlowCard: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions
    /// 期限の DatePicker の日の区切り
    let timeZone: () -> TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            page
                .id(content.page)
                .transition(pageTransition)
        }
        .animation(reduceMotion ? .easeInOut : .default, value: content.page)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal-setup-flow")
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 「視差効果を減らす」では、ページの横移動をフェードにする
    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity)
    }

    /// 残りの手順は数字を出さず、押せない点だけで示す。VoiceOver では「何問目／全部で何問」を読む
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("目標を立てる")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("閉じる", action: actions.close)
                    .font(.subheadline)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("goal-setup-close")
            }
            HStack(spacing: 6) {
                ForEach(0..<content.progress.count, id: \.self) { index in
                    Circle()
                        .fill(
                            index == content.progress.index
                                ? Color.accentColor : Color(.tertiaryLabel)
                        )
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(content.progress.index + 1)問目、全部で\(content.progress.count)問")
            .accessibilityIdentifier("goal-setup-progress")
        }
    }

    @ViewBuilder private var page: some View {
        switch content.page {
        case .direction:
            GoalSetupDirectionPage(content: content, actions: actions)
        case .deadline:
            GoalSetupDeadlinePage(content: content, actions: actions, timeZone: timeZone)
        case .awaitingPreview:
            waitingPage
        case .missingValues:
            GoalSetupMissingValuesPage(content: content, actions: actions)
        case .proposals:
            GoalSetupProposalsPage(content: content, actions: actions)
        case .customTargetWeight:
            GoalSetupCustomTargetWeightPage(content: content, actions: actions)
        case .maintenance:
            GoalSetupMaintenancePage(content: content, actions: actions)
        case .loseUnavailable:
            loseUnavailablePage
        case .stopped(let place):
            stoppedPage(place)
        }
    }

    /// 次が分かるまで（下見の答えを待つ）。その場に回る印を出す
    private var waitingPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
            GoalSetupFooter(page: content.page, goBack: actions.goBack) { EmptyView() }
        }
    }

    private var loseUnavailablePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                "1日の目安が \(NutritionText.kilocalories(DailyGuide.minimumEnergyKilocalories)) を下回るため、減量の目標案を出せません。今の体重を保つ目標は立てられます。"
            )
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            GoalSetupFooter(page: content.page, goBack: actions.goBack) {
                Button("維持にする", action: actions.chooseMaintainInstead)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("goal-setup-maintain-instead")
            }
        }
    }

    /// 電波が無くて、下見か目標案の答えが要る場所で止まった。答えは残す
    private func stoppedPage(_ place: GoalSetupPage.StopPlace) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(GoalSetupUnreachableText.stopped(place))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal-setup-unreachable")
            GoalSetupFooter(page: content.page, goBack: actions.goBack) {
                GoalSetupRetryButton(retry: actions.retry)
            }
        }
    }
}
