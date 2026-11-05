import SwiftUI

extension View {
    /// 目標の画面と目標を決めるページの、文字だけのリンクの見た目（出し方のリンクと出典の入口）。
    /// 文字だけで見た目が小さいので、DESIGN.md の「押せる範囲は 44 以上」に合わせて押せる範囲を広げる
    func goalTextLinkStyle() -> some View {
        font(.footnote)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}
