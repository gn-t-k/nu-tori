import SwiftUI

/// 文字を囲む、枠線だけの小さな印（DESIGN.md の estimate-badge）。出す文字だけを替えて、推定の印と「表示」の印に使う
struct OutlinedBadge: View {
    let text: String

    /// 推定したままの量に添える。食事の画面の料理の行と、料理の画面の量に添える
    static let estimate = OutlinedBadge(text: "推定")
    /// 栄養の出どころが栄養成分表示の材料に添える。料理の画面の材料の行にだけ添える
    static let nutritionLabel = OutlinedBadge(text: "表示")

    var body: some View {
        Text(text)
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
