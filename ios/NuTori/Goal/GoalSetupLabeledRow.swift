import SwiftUI

/// 名前と欄の1行。大きな文字では、欄に押されて名前や単位が1字ずつ折れるので、名前の下に欄を置く
struct GoalSetupLabeledRow<Field: View>: View {
    let label: String
    @ViewBuilder let field: () -> Field
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ label: String, @ViewBuilder field: @escaping () -> Field) {
        self.label = label
        self.field = field
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                // 欄が同じ名前で読み上げられるので、名前は読み上げない
                Text(label)
                    .accessibilityHidden(true)
                field()
            }
        } else {
            LabeledContent(label, content: field)
        }
    }
}
