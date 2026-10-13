import UIKit

/// 画面に出たときに全体を選ぶ、書き換えられない文の欄
final class SelectingTextView: UITextView, UITextViewDelegate {
    var onEnd: () -> Void = {}

    /// 描く文を入れる。同じ文なら入れ直さない（入れ直すと、選んだ範囲が外れる）。
    /// UITextView から読み戻した文は、入れた文と属性が変わることがあるので、入れた文を覚えて比べる
    func show(_ text: NSAttributedString) {
        guard text != shownText else { return }
        shownText = text
        attributedText = text
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, phase == .waiting else { return }
        delegate = self
        becomeFirstResponder()
        selectAll(nil)
        phase = .selecting
    }

    /// タイムラインの余白を押したとき、書く欄にカーソルを移したときに呼ばれる
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            end()
        }
        return resigned
    }

    /// 文の上を押して、選んだ範囲を外したとき
    func textViewDidChangeSelection(_ textView: UITextView) {
        if selectedRange.length == 0 {
            end()
        }
    }

    private enum Phase {
        /// 画面に出る前
        case waiting
        case selecting
        case ended
    }

    private var phase = Phase.waiting
    private var shownText: NSAttributedString?

    private func end() {
        guard phase == .selecting else { return }
        phase = .ended
        // 欄を画面から外す書き換えを、UIKit の呼び出しの途中で起こさない
        Task { @MainActor in
            onEnd()
        }
    }
}
