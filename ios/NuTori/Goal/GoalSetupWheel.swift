import SwiftUI

/// シートに並べるホイールの1本
struct GoalSetupWheel<Choices: View>: View {
    let label: String
    @Binding var selection: Int
    let identifier: String
    @ViewBuilder let choices: () -> Choices

    init(
        _ label: String, selection: Binding<Int>, identifier: String,
        @ViewBuilder choices: @escaping () -> Choices
    ) {
        self.label = label
        _selection = selection
        self.identifier = identifier
        self.choices = choices
    }

    var body: some View {
        Picker(label, selection: $selection, content: choices)
            .pickerStyle(.wheel)
            .labelsHidden()
            // 2本並べたとき、互いの押せる範囲が重ならないよう、幅を分けて切る
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier(identifier)
    }
}
