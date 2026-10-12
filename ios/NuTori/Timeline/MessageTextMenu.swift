import SwiftUI
import UIKit

/// 発言の文（送った文章の吹き出し、返事）を長押ししたときのメニュー。
/// 「コピー」は発言の全体をコピーし、「テキストを選択」はその場で範囲を選べる形（`SelectableText`）に変える
struct MessageTextMenu: ViewModifier {
    /// 「コピー」でコピーする、発言の全体。押したときに作る
    let copyText: () -> String
    /// false のあいだは、長押ししてもメニューを出さない
    let isEnabled: Bool
    @Binding var isSelecting: Bool

    func body(content: Content) -> some View {
        content.contextMenu {
            // 範囲を選んでいるあいだは出さない。長押しは、選ぶ範囲を動かす操作になる
            if isEnabled && !isSelecting {
                Button("コピー", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = copyText()
                }
                Button("テキストを選択", systemImage: "character.cursor.ibeam") {
                    isSelecting = true
                }
            }
        }
    }
}
