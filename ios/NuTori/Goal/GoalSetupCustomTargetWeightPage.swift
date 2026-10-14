import NuToriAPI
import NuToriCore
import SwiftUI

/// 自分で決める目標体重のページ。上に体重の記録と同じステッパー（0.1 kg ずつ、値を押すとキーボード）、下に受け付ける幅だけ動くスライダー。
/// 受け付ける端で − か ＋ が押せなくなり、外の値は端の値に直して1行を添える。
/// 答えが届くまでは前の1日の目安と大変さのひとことを薄くし、横に回る印を出す。「この目標で始める」はいつも押せる
struct GoalSetupCustomTargetWeightPage: View {
    let flow: GoalSetupFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GoalSetupUsedValuesLine(flow: flow)
            Text("\(GoalSetupDayText.monthDay(flow.deadline))までの目標体重を決める")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if let custom = flow.customTargetWeight {
                Group {
                    stepper(custom)
                    slider(custom)
                    assessment(custom)
                    if let note = correctionText(custom) {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("goal-setup-custom-corrected")
                    }
                }
                .opacity(isDeciding ? 0.4 : 1)
                .disabled(isDeciding)
            }
            if flow.showsRecalculated {
                Text("新しい体重で計算し直しました。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let unreachable = unreachableText {
                Text(unreachable)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("goal-setup-unreachable")
            }
            GoalSetupStartButton(
                flow: flow, title: "この目標で始める", identifier: "goal-setup-custom-start")
            GoalSetupFooter(flow: flow) {
                if flow.unreachableRequest != nil {
                    GoalSetupRetryButton(flow: flow)
                }
            }
            .opacity(isDeciding ? 0.4 : 1)
            .disabled(isDeciding)
        }
        .onChange(of: typing) { _, focused in
            if !focused {
                commitTyped()
            }
        }
    }

    @State private var typedText = ""
    @State private var showsField = false
    @FocusState private var typing: Bool

    private var isDeciding: Bool {
        flow.decision != .idle
    }

    private var unreachableText: String? {
        switch flow.unreachableRequest {
        case .customTargetWeight: GoalSetupUnreachableText.customTargetWeight
        case .decision: GoalSetupUnreachableText.decision
        case nil: nil
        }
    }

    /// 体重の記録と同じ − と ＋ と値の欄（`WeightEntryControls`）
    private func stepper(_ custom: CustomTargetWeight) -> some View {
        HStack(spacing: 12) {
            WeightStepButton(title: "−", label: "0.1 kg 減らす", enabled: custom.canDecrease) {
                move(to: custom.kilograms - 0.1)
            }
            value(custom)
            WeightStepButton(title: "+", label: "0.1 kg 増やす", enabled: custom.canIncrease) {
                move(to: custom.kilograms + 0.1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func value(_ custom: CustomTargetWeight) -> some View {
        if showsField {
            TextField("", text: $typedText)
                .keyboardType(.decimalPad)
                .font(.title2)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .focused($typing)
                .frame(minWidth: 88)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: weightControlShape)
                .overlay(weightControlShape.stroke(Color.accentColor))
                .onChange(of: typedText) { _, next in
                    let sanitized = WeightDecimalText.sanitized(next)
                    if sanitized != next {
                        typedText = sanitized
                    }
                }
                .accessibilityLabel("目標体重の値")
                .onAppear { typing = true }
        } else {
            Button {
                typedText = ""
                showsField = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(
                        String(
                            format: "%.1f", locale: Locale(identifier: "en_US_POSIX"),
                            custom.kilograms)
                    )
                    .font(.title2)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    Text("kg")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 88)
                .padding(12)
                .background(Color(.tertiarySystemFill), in: weightControlShape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("目標体重")
            .accessibilityValue(WeightAmountText.kilograms(custom.kilograms))
            .accessibilityIdentifier("goal-setup-custom-value")
            .animation(.default, value: custom.kilograms)
        }
    }

    /// 受け付ける幅だけ動くスライダー。ゆるめ・標準・ハードの案の位置に名前を置く
    @ViewBuilder private func slider(_ custom: CustomTargetWeight) -> some View {
        let range = custom.range.minimumKilograms...custom.range.maximumKilograms
        if range.lowerBound < range.upperBound {
            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { custom.kilograms },
                        set: { move(to: $0) }),
                    in: range, step: 0.1
                )
                .accessibilityLabel("目標体重")
                .accessibilityValue(WeightAmountText.kilograms(custom.kilograms))
                paceMarks(in: range)
            }
        }
    }

    private func paceMarks(in range: ClosedRange<Double>) -> some View {
        Text("ゆるめ")
            .font(.caption2)
            .hidden()
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geo in
                    // スライダーのつまみの半分だけ、両端が内側に寄る
                    let inset: CGFloat = 14
                    let width = max(geo.size.width - inset * 2, 0)
                    ForEach(offeredProposals, id: \.pace) { proposal in
                        let fraction =
                            (proposal.targetWeightKilograms - range.lowerBound)
                            / (range.upperBound - range.lowerBound)
                        Text(GoalSetupDifficultyText.paceName(proposal.pace))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .position(
                                x: inset + width * min(max(fraction, 0), 1),
                                y: geo.size.height / 2)
                    }
                }
            }
            .accessibilityHidden(true)
    }

    private var offeredProposals: [GoalProposals.OfferedProposal] {
        guard case .weightChange(let weightChange)? = flow.proposals?.plan else { return [] }
        return weightChange.offeredProposals
    }

    /// この目標体重の1日の目安と大変さのひとこと。届くまでは前の値を薄くし、横に回る印を出す
    private func assessment(_ custom: CustomTargetWeight) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("この目標の1日の目安")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(
                    GoalSetupDifficultyText.kilocalories(
                        custom.assessment.dailyGuide.energyKilocalories)
                )
                .font(.title2)
                .monospacedDigit()
                Text(
                    GoalSetupDifficultyText.difference(
                        custom.assessment.dailyGuideDifferenceKilocalories)
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(custom.isAssessing ? 0.4 : 1)
            Spacer(minLength: 0)
            if custom.isAssessing {
                ProgressView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goal-setup-custom-assessment")
    }

    /// 端の値に直したときの1行
    private func correctionText(_ custom: CustomTargetWeight) -> String? {
        guard let reason = custom.correctedReason else { return nil }
        let deadline = GoalSetupDayText.monthDay(flow.deadline)
        let kilograms = WeightAmountText.kilograms(custom.kilograms)
        switch reason {
        case .dailyGuideBelowMinimum:
            return "1日の目安が 1,200 kcal を下回るため、\(deadline)までに目指せるのは \(kilograms) までです。"
        case .notOnDirectionSide:
            // 仕様に文が無い遅い側の端。体重の傾向より向きの側に出ない目標は立てられないことを、事実だけで書く
            return custom.direction == .lose
                ? "減量では、\(kilograms) より重い目標は立てられません。"
                : "増量では、\(kilograms) より軽い目標は立てられません。"
        case .paceTooFast, .unknown:
            return "\(deadline)までに目指せるのは \(kilograms) までです。"
        }
    }

    private func move(to kilograms: Double) {
        Task { await flow.setCustomTargetWeight(kilograms) }
    }

    /// 打った値は、キーボードを閉じたときに受け取る。外の値は流れが端の値に直す
    private func commitTyped() {
        showsField = false
        let core = typedText.hasSuffix(".") ? String(typedText.dropLast()) : typedText
        guard let kilograms = Double(core.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        move(to: kilograms)
    }
}
