import NuToriCore
import SwiftUI

/// 料理の待ちの1行（`DishRow.Note`）。食事の画面の料理の行の下と、料理の画面の名前の下に置く
struct DishProgressNoteText: View {
    let note: DishRow.Note

    var body: some View {
        HStack(spacing: 8) {
            // 推定の待っている表示。サーバーが処理しているあいだだけ出す
            if note.showsSpinner {
                ProgressView()
            }
            Text(note.text)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
