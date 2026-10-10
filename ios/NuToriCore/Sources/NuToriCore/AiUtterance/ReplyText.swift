import Foundation

/// 返事の本文を、描く書式（段落・箇条書き・番号つきの箇条書き・太字）の行に分けたもの。
/// 指示で書かせる書式はこれだけで、ほかの記法はそのまま文字として描く（混じるかは使いながら見る）
public struct ReplyText: Hashable, Sendable {
    public let lines: [Line]

    /// 伸びている途中の本文も読む。閉じていない「**」は、記号を見せずにそこから先を太字にする
    public init(_ body: String) {
        var lines: [Line] = []
        var paragraph: [Substring] = []
        func closeParagraph() {
            guard !paragraph.isEmpty else { return }
            lines.append(Line(.paragraph, Self.runs(paragraph.joined(separator: "\n"))))
            paragraph = []
        }
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            if raw.allSatisfy(\.isWhitespace) {
                closeParagraph()
            } else if let item = Self.bulletItem(raw) {
                closeParagraph()
                lines.append(Line(.bullet, Self.runs(String(item))))
            } else if let (number, item) = Self.numberedItem(raw) {
                closeParagraph()
                lines.append(Line(.numbered(number), Self.runs(String(item))))
            } else {
                paragraph.append(raw)
            }
        }
        closeParagraph()
        self.lines = lines
    }

    public struct Line: Hashable, Sendable {
        public let kind: Kind
        public let runs: [Run]

        public init(_ kind: Kind, _ runs: [Run]) {
            self.kind = kind
            self.runs = runs
        }
    }

    public enum Kind: Hashable, Sendable {
        case paragraph
        case bullet
        case numbered(Int)
    }

    public enum Run: Hashable, Sendable {
        case plain(String)
        case bold(String)
    }

    private static func bulletItem(_ line: Substring) -> Substring? {
        for marker in ["- ", "* "] where line.hasPrefix(marker) {
            return line.dropFirst(marker.count)
        }
        return nil
    }

    private static func numberedItem(_ line: Substring) -> (Int, Substring)? {
        let digits = line.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let number = Int(digits),
            line.dropFirst(digits.count).hasPrefix(". ")
        else { return nil }
        return (number, line.dropFirst(digits.count + 2))
    }

    /// 「**」で区切り、奇数番目を太字にする。空の区切りは捨てる
    private static func runs(_ text: String) -> [Run] {
        text.components(separatedBy: "**").enumerated().compactMap { index, part in
            guard !part.isEmpty else { return nil }
            return index.isMultiple(of: 2) ? .plain(part) : .bold(part)
        }
    }
}
