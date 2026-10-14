import SwiftUI

/// − と ＋ のあいだの体重の値。押すとキーボードで入れる欄になり（DESIGN.md の value-field）、欄から離れると値に戻る。
/// 体重の記録と、自分で決める目標体重で同じものを使う
struct WeightValueField: View {
    /// 値に戻っているときに見せる数（まだ無ければ「–」）
    let shownText: String
    /// 欄の文字
    @Binding var text: String
    /// 欄にしているか。フォーカスは欄が出てから当てる（欄が無いうちに当てると、すぐ外れて欄が出ない）
    @Binding var showsField: Bool
    let typing: FocusState<Bool>.Binding
    /// 欄の読み上げの名前
    let fieldLabel: String
    /// 値に戻っているときの読み上げの名前と値
    let shownLabel: String
    let shownValue: String?
    /// 値を押して、欄にする直前
    let beginTyping: () -> Void
    /// 欄の文字が変わった
    let textChanged: (_ previous: String, _ next: String) -> Void
    /// 欄から離れて、値に戻った
    let endTyping: () -> Void

    var body: some View {
        if showsField {
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .font(.title2)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .focused(typing)
                .frame(minWidth: 88)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: WeightStepButton.shape)
                .overlay(WeightStepButton.shape.stroke(Color.accentColor))
                .onChange(of: text) { previous, next in
                    textChanged(previous, next)
                }
                .accessibilityLabel(fieldLabel)
                .onAppear { typing.wrappedValue = true }
                .onChange(of: typing.wrappedValue) { _, focused in
                    if !focused {
                        showsField = false
                        endTyping()
                    }
                }
        } else {
            Button {
                beginTyping()
                showsField = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(shownText)
                        .font(.title2)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("kg")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 88)
                .padding(12)
                .background(Color(.tertiarySystemFill), in: WeightStepButton.shape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(shownLabel)
            .accessibilityValue(shownValue ?? "")
            .animation(.default, value: shownText)
        }
    }
}
