import SwiftUI

/// 推定したままの量に添える、枠線だけの小さな印（DESIGN.md の estimate-badge）。食事の画面の料理の行と、料理の画面の量に添える
struct EstimateBadge: View {
    var body: some View {
        Text("推定")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.secondary, lineWidth: 1)
            }
    }
}
