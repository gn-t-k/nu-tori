import NuToriCore
import SwiftUI

/// タイムラインの目標を立てる知らせのカード。広げる前、広げた目標の設定の流れ、決まったあとの3つの形をとる。
/// 「あとで」のあとも、目標が決まったあとも、タイムラインに残る
struct GoalSetupNoticeCard: View {
    let notice: Notice
    /// 今の目標。決まっていれば、決めた目標を示す形にする
    let currentGoal: CurrentGoal?
    /// 目標が決まっていないときの、目標の設定の流れの形
    let flow: Flow
    let timeZone: () -> TimeZone
    /// 知らせの「あとで」
    let answerLater: () -> Void
    /// 「目標を立てる」「続ける」。開くところを添えて、カードを広げる
    let open: (GoalSetupObservation.Entry) -> Void

    var body: some View {
        Group {
            if let currentGoal {
                GoalDecidedCard(goal: currentGoal.goal, dailyGuide: currentGoal.dailyGuide)
            } else if case .expanded(let content, let actions) = flow {
                GoalSetupFlowCard(content: content, actions: actions, timeZone: timeZone)
                    .transition(expansion)
            } else {
                closedCard
                    .transition(expansion)
            }
        }
        .animation(reduceMotion ? .easeInOut : .default, value: form)
    }

    /// 目標の設定の流れの形。外側が流れ（`GoalSetupFlow`）から読んで渡す
    enum Flow {
        /// まだ開いていないか、決めたあと。「目標を立てる」
        case notStarted
        /// 途中まで進めて閉じた。「続ける」で同じページから
        case paused
        /// 広げている
        case expanded(GoalSetupFlowContent, GoalSetupFlowActions)

        /// 広げているページ。広げていなければ nil
        var expandedPage: GoalSetupPage? {
            switch self {
            case .notStarted, .paused: nil
            case .expanded(let content, _): content.page
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Form: Equatable {
        case decided
        case expanded
        case closed
    }

    private var isPaused: Bool {
        if case .paused = flow { true } else { false }
    }

    private var form: Form {
        if currentGoal != nil { return .decided }
        return flow.expandedPage == nil ? .closed : .expanded
    }

    /// 「視差効果を減らす」では、カードの広がりをフェードにする
    private var expansion: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    }

    private var closedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("目標を立てる")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(
                    WeightAmountText.clock(
                        ClockTime(containing: notice.issuedAt, in: notice.timeZone))
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Text("目標を立てると、1日に食べる量の目安が出ます。")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            // DESIGN.md のボタン: 主な操作は塗ったボタン、並べる副の操作（あとで）は灰色のボタン。大きな文字では縦に並べる
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    buttons
                }
                VStack(alignment: .trailing, spacing: 12) {
                    buttons
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal-setup-notice")
    }

    /// 「あとで」は答えていないあいだだけ。押すと帯の下の1行が消え、カードは残る
    @ViewBuilder private var buttons: some View {
        if notice.response == nil {
            Button("あとで", action: answerLater)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("goal-setup-later")
        }
        Button(isPaused ? "続ける" : "目標を立てる") {
            open(.noticeCard)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("goal-setup-start")
    }
}

extension GoalSetupNoticeCard.Flow {
    /// 開いたことのある流れから。まだ開いていなければ nil
    @MainActor
    init(_ flow: GoalSetupFlow?) {
        guard let flow else {
            self = .notStarted
            return
        }
        if flow.isOpen {
            self = .expanded(
                GoalSetupFlowContent(flow), GoalSetupFlowActions(flow, close: flow.close))
        } else {
            self = flow.hasProgress ? .paused : .notStarted
        }
    }
}
