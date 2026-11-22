import NuToriCore
import SwiftUI

/// タイムラインの目標を立てる知らせのカード。広げる前、広げた目標の設定の流れ、決まったあとの3つの形をとる。
/// 目標が決まったあとも、タイムラインに残る
struct GoalSetupNoticeCard: View {
    /// 今の目標。決まっていれば、決めた目標を示す形にする
    let currentGoal: CurrentGoal?
    /// 目標が決まっていないときの、目標の設定の流れの形
    let flow: Flow
    let timeZone: () -> TimeZone
    /// 「目標を立てる」「続ける」。開くところを添えて、カードを広げる
    let open: (GoalSetupObservation.Entry) -> Void

    var body: some View {
        // Group に付けた修飾子は中の形ごとに付き、形が替わると新しい形の修飾子が最初の値から始まって、弾みも触覚も起きない。入れ物1つに付ける
        ZStack {
            if let currentGoal {
                GoalDecidedCard(goal: currentGoal.goal, dailyGuide: currentGoal.dailyGuide)
                    .transition(decided)
            } else if case .expanded(let content, let actions) = flow {
                GoalSetupFlowCard(content: content, actions: actions, timeZone: timeZone)
                    .transition(expansion)
            } else {
                closedCard
                    .transition(expansion)
            }
        }
        .animation(animation(to: form), value: form)
        // 目標が決まった瞬間に、決まったカードが入るのと同時に鳴らす。開いたときにもう決まっていれば、形が変わらないので鳴らない
        .sensoryFeedback(.success, trigger: form) { old, new in
            old != .decided && new == .decided
        }
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

    /// 目標が決まったときだけ、少し弾ませる。数か月に1回の気持ちが動く場面なので、弾みはここにだけ使う（DESIGN.md の Motion）
    private func animation(to form: Form) -> Animation {
        if reduceMotion { return .easeInOut }
        return form == .decided ? .spring(duration: 0.4, bounce: 0.15) : .default
    }

    /// 決まったカードは 96% から入る。「視差効果を減らす」ではフェードにする
    private var decided: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    /// 「視差効果を減らす」では、カードの広がりをフェードにする。
    /// 抜けるときは薄れるだけにし、目標が決まったときに弾むのを決まったカードだけにする
    private var expansion: AnyTransition {
        .asymmetric(
            insertion: reduceMotion
                ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity)
    }

    private var closedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目標を立てる")
                .font(.subheadline.weight(.semibold))
            Text("目標を立てると、1日に食べる量の目安が出ます。")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            // 答えないままにしておくことが「あとで」になるので、断るボタンは置かない
            Button(isPaused ? "続ける" : "目標を立てる") {
                open(.noticeCard)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("goal-setup-start")
            .frame(maxWidth: .infinity, alignment: .trailing)
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
}

extension GoalSetupNoticeCard.Flow {
    /// 開いたことのある流れから、その場所に描く形を出す。広げた流れは、開いた場所にだけ広げ、ほかの場所では途中まで進めた形にする
    /// - Parameters:
    ///   - flow: まだ開いていなければ nil
    ///   - place: 描く場所
    ///   - openedPlace: 流れを最後に開いた場所
    @MainActor
    init(
        _ flow: GoalSetupFlow?, on place: GoalSetupSession.Place,
        openedOn openedPlace: GoalSetupSession.Place
    ) {
        guard let flow else {
            self = .notStarted
            return
        }
        if flow.isOpen, place != openedPlace {
            self = .paused
        } else if flow.isOpen {
            self = .expanded(
                GoalSetupFlowContent(flow), GoalSetupFlowActions(flow, close: flow.close))
        } else {
            self = flow.hasProgress ? .paused : .notStarted
        }
    }
}
