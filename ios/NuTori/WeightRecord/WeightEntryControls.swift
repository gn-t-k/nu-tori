import NuToriCore
import SwiftUI

/// 体重のステッパーと値の欄、前回の値と打ち間違いの添え書き。体重のシートと体重の知らせの中で同じものを使う
struct WeightEntryControls: View {
    let entry: WeightEntry
    @Binding var draft: WeightDraft
    @Binding var observation: WeightEntryObservation
    let typing: FocusState<Bool>.Binding
    /// 開いたときから、値の欄をキーボードで入れる形にする（前回の値が無い体重のシート）
    let startsTyping: Bool
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
        .onAppear {
            if startsTyping {
                showsField = true
            }
        }
    }

    /// 値の欄を入れる欄にしているか。フォーカスは欄が出てから当てる（欄が無いうちに当てると、すぐ外れて欄が出ない）
    @State private var showsField = false

    /// ステッパーが入れた文字列。キーボードの変更通知が、その変更を打鍵と数えないため
    @State private var textFromStep: String?

    private var value: some View {
        WeightValueField(
            // 前回の値が無く、まだ入れていないとき（知らせの中はキーボードを自動で出さない）
            shownText: draft.text.isEmpty ? "–" : draft.text,
            text: $draft.text,
            showsField: $showsField,
            typing: typing,
            fieldLabel: "体重の値",
            // まだ入れていないときは、見た目の「–」に合わせて値を読まず、入れる欄だと伝える
            shownLabel: draft.kilograms.map(WeightAmountText.kilograms) ?? "体重の値",
            shownValue: nil,
            beginTyping: {
                draft.beginTyping()
                onBeginTyping()
            },
            textChanged: { previous, next in
                if next == textFromStep {
                    textFromStep = nil
                    return
                }
                draft.applyTyped(previous: previous, next: next)
                observation.typed()
            },
            endTyping: {}
        )
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
