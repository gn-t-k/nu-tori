import NuToriCore
import SwiftUI

/// タイムラインの目標を立てる知らせのカード。広げる前、広げた目標の設定の流れ、決まったあとの3つの形をとる。
/// 「あとで」のあとも、目標が決まったあとも、タイムラインに残る
struct GoalSetupNoticeCard: View {
    let notice: Notice
    /// 今の目標。決まっていれば、決めた目標を示す形にする
    let goal: Goal?
    /// 今の目標の1日の目安。まだ届いていなければ nil
    let dailyGuide: DailyGuide?
    let session: GoalSetupSession
    let timeZone: () -> TimeZone
    /// 「目標を立てる」「続ける」。開くところを添えて、カードを広げる
    let open: (GoalSetupObservation.Entry) -> Void

    var body: some View {
        Group {
            if let goal {
                GoalDecidedCard(goal: goal, dailyGuide: dailyGuide)
            } else if let flow = session.flow, flow.isOpen {
                GoalSetupFlowCard(flow: flow, timeZone: timeZone, close: session.close)
                    .transition(expansion)
            } else {
                closedCard
                    .transition(expansion)
            }
        }
        .animation(reduceMotion ? .easeInOut : .default, value: form)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Form: Equatable {
        case decided
        case expanded
        case closed
    }

    private var form: Form {
        if goal != nil { return .decided }
        return session.isOpen ? .expanded : .closed
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
            Button("あとで") {
                Task { await session.later() }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("goal-setup-later")
        }
        Button(session.hasProgress ? "続ける" : "目標を立てる") {
            open(.noticeCard)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("goal-setup-start")
    }
}
