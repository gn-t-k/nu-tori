#if DEBUG
    import SwiftUI

    #Preview {
        @Previewable @State var whole = 65
        @Previewable @State var tenth = 0
        GoalSetupWheelSheet(
            title: "今の体重", confirm: {},
            wheels: {
                Picker("今の体重の整数", selection: $whole) {
                    ForEach(20...300, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                Picker("今の体重の小数", selection: $tenth) {
                    ForEach(0...9, id: \.self) { Text(verbatim: ".\($0) kg").tag($0) }
                }
                .pickerStyle(.wheel)
            })
    }
#endif
