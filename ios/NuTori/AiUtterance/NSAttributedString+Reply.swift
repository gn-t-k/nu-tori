import NuToriCore
import UIKit

extension NSAttributedString {
    /// 返事の文を、範囲を選べる形（`SelectableText`）で描くときの文。
    /// `ReplyTextView` と同じ場所に文字が来るよう、段落・箇条書き・番号つきの箇条書き・太字で描く
    static func reply(_ text: ReplyText) -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let boldFont = font.fontDescriptor.withSymbolicTraits(.traitBold).map {
            UIFont(descriptor: $0, size: 0)
        }
        // SwiftUI の VStack と HStack の標準の間隔
        let spacing: CGFloat = 8
        let result = NSMutableAttributedString()
        for (index, line) in text.lines.enumerated() {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = spacing
            var runs = line.runs
            if let marker = line.marker {
                // 印の右に文をそろえ、折り返した行も同じ位置から始める
                let indent =
                    (marker as NSString).size(withAttributes: [.font: font]).width + spacing
                style.tabStops = [NSTextTab(textAlignment: .natural, location: indent)]
                style.headIndent = indent
                runs.insert(.plain(marker + "\t"), at: 0)
            }
            let lineText = NSMutableAttributedString()
            for run in runs {
                let runFont =
                    switch run {
                    case .plain: font
                    case .bold: boldFont ?? font
                    }
                lineText.append(
                    NSAttributedString(
                        string: run.text,
                        attributes: [
                            .font: runFont, .foregroundColor: UIColor.label, .paragraphStyle: style,
                        ]))
            }
            // 段落の中の改行のあとは、行のあいだを空けない（SwiftUI の Text と同じ）
            let lastBreak = (lineText.string as NSString).range(of: "\n", options: .backwards)
            if lastBreak.location != NSNotFound {
                let tight = NSMutableParagraphStyle()
                tight.setParagraphStyle(style)
                tight.paragraphSpacing = 0
                lineText.addAttribute(
                    .paragraphStyle, value: tight,
                    range: NSRange(location: 0, length: lastBreak.location + 1))
            }
            if index < text.lines.count - 1 {
                lineText.append(
                    NSAttributedString(
                        string: "\n", attributes: [.font: font, .paragraphStyle: style]))
            }
            result.append(lineText)
        }
        return result
    }
}
