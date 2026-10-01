#if DEBUG
    import SwiftUI

    #Preview("食事を削除する確かめ") {
        // シートに載せると、出てくる途中の動きを描いてしまう。中身だけを描く
        BottomConfirmationSheet(
            message: "この食事と料理がすべて削除されます。ヘルスケアに書き出した分も削除します。",
            destructiveTitle: "食事を削除",
            identifierPrefix: "meal-delete",
            onConfirm: {},
            onCancel: {}
        )
        .background(Color(.systemGroupedBackground))
    }
#endif
