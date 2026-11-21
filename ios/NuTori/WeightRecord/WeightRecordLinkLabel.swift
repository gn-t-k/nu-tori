import SwiftUI

/// 外側の余白とボタンの形は置く画面が決める
struct WeightRecordLinkLabel: View {
    var body: some View {
        HStack {
            Text("体重の記録")
                .foregroundStyle(Color.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
    }
}
