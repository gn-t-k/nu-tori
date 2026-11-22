#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview {
        @Previewable @State var whole = 65
        @Previewable @State var tenth = 0
        GoalSetupWheelSheet(
            title: "今の体重", confirm: {},
            wheels: {
                GoalSetupWheel("今の体重の整数", selection: $whole, identifier: "whole") {
                    ForEach(GoalSetupMissingValues.weightWholeChoices, id: \.self) {
                        Text(verbatim: "\($0)").tag($0)
                    }
                }
                GoalSetupWheel("今の体重の小数", selection: $tenth, identifier: "tenth") {
                    ForEach(GoalSetupMissingValues.weightTenthChoices(whole: whole), id: \.self) {
                        Text(verbatim: ".\($0) kg").tag($0)
                    }
                }
            })
    }
#endif
