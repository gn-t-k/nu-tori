import UIKit

extension NSAttributedString {
    /// 送った文章の吹き出しの文を、範囲を選べる形（`SelectableText`）で描くときの文。会話の文字は Body
    static func sentText(_ body: String) -> NSAttributedString {
        NSAttributedString(
            string: body,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.white,
            ])
    }
}
