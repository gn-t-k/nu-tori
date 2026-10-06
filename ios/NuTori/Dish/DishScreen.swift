import Foundation
import NuToriCore
import SwiftUI

/// 料理の画面。食事の画面の料理の行からプッシュで潜る。題は料理の名前で、戻るは「‹ 食事」。
/// 名前と量、材料、栄養の内訳、「この料理を削除」は、まだ置いていない（枠だけ）
struct DishScreen: View {
    let contents: DishContents

    var body: some View {
        List {}
            .navigationTitle(contents.dish.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// 料理の画面へ潜る行き先。画面は、そのときの食事のカードから料理の ID で引いて描く
nonisolated struct DishRoute: Hashable {
    let dishId: UUID
}

/// 開いている料理が消えたら（ほかの端末で消して同期で届いた）、食事の画面に戻る
struct DishDestination: View {
    let contents: DishContents?

    var body: some View {
        if let contents {
            DishScreen(contents: contents)
        } else {
            Color(.systemGroupedBackground)
                .onAppear {
                    dismiss()
                }
        }
    }

    @Environment(\.dismiss) private var dismiss
}
