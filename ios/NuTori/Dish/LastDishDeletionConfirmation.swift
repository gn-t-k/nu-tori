import SwiftUI

/// 最後の1品を消すときだけ出す確かめ（`confirmationDialog`）。食事の画面で左へ送った料理の行と、
/// 料理の画面の「この料理を削除」のボタンに付け、押したもののそばに出す。「食事を削除」で料理でなく食事を消し、「キャンセル」なら料理も残る
struct LastDishDeletionConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    /// 「食事を削除」。食事を消す書き込みを送り、タイムラインに戻る
    let deleteMeal: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "最後の料理です。この食事と写真がすべて削除されます。ヘルスケアに書き出した分も削除します。",
                isPresented: $isPresented, titleVisibility: .visible
            ) {
                Button("食事を削除", role: .destructive, action: deleteMeal)
                Button("キャンセル", role: .cancel) {}
            }
    }
}
