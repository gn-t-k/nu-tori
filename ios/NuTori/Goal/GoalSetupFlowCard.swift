import NuToriAPI
import NuToriCore
import SwiftUI

/// 目標を立てる知らせのカードを広げた形。1ページに1つの問いで、ページを送って進む（`06-layout.md`「目標の設定の流れ」の「カードの振る舞い」）。
/// カードの中はスクロールさせず、タイムラインごと送る。「閉じる」はどのページでも右上、「戻る」は2ページ目から左下に置く
struct GoalSetupFlowCard: View {
    let flow: GoalSetupFlow
    /// 期限の DatePicker の日の区切り
    let timeZone: () -> TimeZone
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            page
                .id(GoalSetupPageKey(flow.page))
                .transition(pageTransition)
        }
        .animation(reduceMotion ? .easeInOut : .default, value: GoalSetupPageKey(flow.page))
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
                Button("閉じる", action: close)
                    .font(.subheadline)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("goal-setup-close")
            }
            HStack(spacing: 6) {
                ForEach(0..<flow.progress.count, id: \.self) { index in
                    Circle()
                        .fill(
                            index == flow.progress.index ? Color.accentColor : Color(.tertiaryLabel)
                        )
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(flow.progress.index + 1)問目、全部で\(flow.progress.count)問")
            .accessibilityIdentifier("goal-setup-progress")
        }
    }

    @ViewBuilder private var page: some View {
        switch flow.page {
        case .direction:
            GoalSetupDirectionPage(flow: flow)
        case .deadline:
            GoalSetupDeadlinePage(flow: flow, timeZone: timeZone)
        case .awaitingPreview:
            waitingPage
        case .missingValues:
            GoalSetupMissingValuesPage(flow: flow)
        case .proposals:
            GoalSetupProposalsPage(flow: flow)
        case .customTargetWeight:
            GoalSetupCustomTargetWeightPage(flow: flow)
        case .maintenance:
            GoalSetupMaintenancePage(flow: flow)
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
            GoalSetupFooter(flow: flow) { EmptyView() }
        }
    }

    private var loseUnavailablePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1日の目安が 1,200 kcal を下回るため、減量の目標案を出せません。今の体重を保つ目標は立てられます。")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            GoalSetupFooter(flow: flow) {
                Button("維持にする") {
                    Task { await flow.chooseMaintainInstead() }
                }
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
            GoalSetupFooter(flow: flow) {
                GoalSetupRetryButton(flow: flow)
            }
        }
    }
}

/// ページの下の行。左下に「戻る」（2ページ目から）、右に、そのページの主な操作
struct GoalSetupFooter<Primary: View>: View {
    let flow: GoalSetupFlow
    @ViewBuilder let primary: () -> Primary

    var body: some View {
        HStack(spacing: 12) {
            if flow.page != .direction {
                Button("戻る") {
                    flow.goBack()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("goal-setup-back")
            }
            Spacer(minLength: 0)
            primary()
        }
    }
}

/// つながらなかった要求をもう一度出す
struct GoalSetupRetryButton: View {
    let flow: GoalSetupFlow

    var body: some View {
        Button("もう一度試す") {
            Task { await flow.retry() }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("goal-setup-retry")
    }
}

/// インターネットにつながらないときの1行。DESIGN.md の Don't のとおり、つながるとできることを書く
enum GoalSetupUnreachableText {
    static func stopped(_ place: GoalSetupPage.StopPlace) -> String {
        switch place {
        case .beforeMissingValues:
            "ここまでの答えは残してあります。インターネットにつながると、続きに進めます。"
        case .beforeProposals:
            "ここまでの答えは残してあります。インターネットにつながると、目標案を出せます。"
        }
    }

    /// 自分で決める目標体重の要求が届かなかった
    static let customTargetWeight = "ここまでの答えは残してあります。インターネットにつながると、1日の目安を出せます。"

    /// 目標を決める要求が届かなかった
    static let decision = "ここまでの答えは残してあります。インターネットにつながると、目標を決められます。"
}

/// ページを見分ける値。ページが替わったときの動きと、ページを送ったあとの自動のスクロールに使う
struct GoalSetupPageKey: Hashable {
    init(_ page: GoalSetupPage) {
        name =
            switch page {
            case .direction: "direction"
            case .deadline: "deadline"
            case .awaitingPreview: "awaiting-preview"
            case .missingValues: "missing-values"
            case .proposals: "proposals"
            case .customTargetWeight: "custom-target-weight"
            case .maintenance: "maintenance"
            case .loseUnavailable: "lose-unavailable"
            case .stopped(.beforeMissingValues): "stopped-before-missing-values"
            case .stopped(.beforeProposals): "stopped-before-proposals"
            }
    }

    private let name: String
}
