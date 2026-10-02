import NuToriCore
import SwiftUI

/// 体重のステッパーと値の欄、前回の値と打ち間違いの添え書き。体重のシートと体重の知らせの中で同じものを使う
struct WeightEntryControls: View {
    let entry: WeightEntry
    @Binding var draft: WeightDraft
    @Binding var observation: WeightEntryObservation
    let typing: FocusState<Bool>.Binding
    /// 値を押してキーボードで入れ始めたとき
    let onBeginTyping: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                WeightStepButton(title: "−", label: "0.1 kg 減らす", enabled: canDecrease) {
                    step(by: -1)
                }
                value
                WeightStepButton(title: "+", label: "0.1 kg 増やす", enabled: canIncrease) {
                    step(by: 1)
                }
            }
            if let previousText {
                Text(previousText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let typoText {
                Text(typoText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onChange(of: typoText != nil, initial: true) { _, isShowing in
            if isShowing {
                observation.noteTypoHintShown()
            }
        }
    }

    /// ステッパーが入れた文字列。キーボードの変更通知が、その変更を打鍵と数えないため
    @State private var textFromStep: String?

    @ViewBuilder private var value: some View {
        if typing.wrappedValue {
            TextField("", text: $draft.text)
                .keyboardType(.decimalPad)
                .font(.title2)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .focused(typing)
                .frame(minWidth: 88)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: weightControlShape)
                .overlay(weightControlShape.stroke(Color.accentColor))
                .onChange(of: draft.text) { previous, next in
                    if next == textFromStep {
                        textFromStep = nil
                        return
                    }
                    draft.applyTyped(previous: previous, next: next)
                    observation.typed()
                }
                .accessibilityLabel("体重の値")
        } else {
            Button {
                draft.beginTyping()
                typing.wrappedValue = true
                onBeginTyping()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // 前回の値が無く、まだ入れていないとき（知らせの中はキーボードを自動で出さない）
                    Text(draft.text.isEmpty ? "–" : draft.text)
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
            .accessibilityLabel(WeightAmountText.kilograms(draft.kilograms ?? 0))
            .animation(.default, value: draft.tenths)
        }
    }

    private var canDecrease: Bool {
        guard let tenths = draft.tenths else { return false }
        return tenths > WeightDraft.minimumTenths
    }

    private var canIncrease: Bool {
        guard let tenths = draft.tenths else { return false }
        return tenths < WeightDraft.maximumTenths
    }

    private var previousText: String? {
        guard case .previous(let kilograms, let day) = entry.initialValue else { return nil }
        return "前回 \(TimelineDayText.label(for: day)) \(WeightAmountText.kilograms(kilograms))"
    }

    private var typoText: String? {
        guard let kilograms = draft.kilograms, let typo = entry.possibleTypo(for: kilograms)
        else { return nil }
        let direction =
            switch typo.direction {
            case .heavier: "重い"
            case .lighter: "軽い"
            }
        let day = "\(typo.previousDay.month)月\(typo.previousDay.day)日"
        let difference = WeightAmountText.kilograms(typo.differenceKilograms)
        return "前回（\(day)）より \(difference) \(direction)値です"
    }

    private func step(by delta: Int) {
        let before = draft.tenths
        draft.step(by: delta)
        if draft.tenths != before {
            observation.stepped()
            textFromStep = draft.text
        }
        typing.wrappedValue = false
    }
}

/// 値の欄とステッパーの角（DESIGN.md の value-field と stepper-button）
private let weightControlShape = RoundedRectangle(cornerRadius: 10)

private struct WeightStepButton: View {
    let title: String
    let label: String
    let enabled: Bool
    let step: () -> Void

    var body: some View {
        Button(action: stepOnce) {
            Text(title)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: weightControlShape)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .onLongPressGesture(minimumDuration: 0.4, pressing: updatePress, perform: {})
        .onDisappear {
            stepTask?.cancel()
        }
    }

    @State private var stepTask: Task<Void, Never>?
    @State private var steppedFromPress = false

    private func stepOnce() {
        if steppedFromPress {
            steppedFromPress = false
            return
        }
        step()
    }

    private func updatePress(_ pressing: Bool) {
        if pressing {
            guard enabled, stepTask == nil else { return }
            steppedFromPress = true
            step()
            stepTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                while !Task.isCancelled {
                    step()
                    try? await Task.sleep(for: .milliseconds(90))
                }
            }
        } else {
            stepTask?.cancel()
            stepTask = nil
        }
    }
}
