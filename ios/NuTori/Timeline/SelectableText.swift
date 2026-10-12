import SwiftUI
import UIKit

/// 「テキストを選択」を選んだ発言の文。その場で範囲を選べ、選んだ範囲を押すと iOS の標準のメニュー（コピーなど）が出る。
/// 出したときに全体を選び、選んだ範囲を外すか、ほかの場所を押すと `onEnd` を呼ぶ。
/// DESIGN.md の「部品は SwiftUI の標準」に従わない。iOS 26 の SwiftUI の Text は範囲を選べないため（`textSelection(_:)` が範囲を選べるのは iOS 27 から）
struct SelectableText: UIViewRepresentable {
    let text: NSAttributedString
    /// 選んだ範囲とつまみの色。nil ならアプリの色
    let tint: UIColor?
    let onEnd: () -> Void

    func makeUIView(context: Context) -> SelectingTextView {
        let view = SelectingTextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        // SwiftUI の Text と同じ場所に文字を置くため、UITextView の内側の余白を無くす
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.accessibilityIdentifier = "selectable-text"
        return view
    }

    func updateUIView(_ view: SelectingTextView, context: Context) {
        view.onEnd = onEnd
        view.tintColor = tint
        view.show(text)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: SelectingTextView, context: Context)
        -> CGSize?
    {
        let width = proposal.width ?? .greatestFiniteMagnitude
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: min(fitting.width.rounded(.up), width), height: fitting.height)
    }
}
