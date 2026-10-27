import Foundation

/// 公開のページ（`site/`）。アプリの中のリンクは、ここの URL を使う
enum PublicPages {
    static let terms = URL(string: "https://nu-tori.app/terms")!
    static let privacyPolicy = URL(string: "https://nu-tori.app/privacy")!
    /// プライバシーポリシーの「利用状況」の項（送るものの一覧）
    static let usageData = URL(string: "https://nu-tori.app/privacy#usage-data")!
    /// 特定商取引法に基づく表記
    static let legal = URL(string: "https://nu-tori.app/legal")!
    /// 1日の目安が、あなたの体に合っていく仕組み（出し方のページ）
    static let dailyGuide = URL(string: "https://nu-tori.app/daily-guide")!

    /// 文の中のリンク（Markdown の `[名前](URL)`）を描ける形にする。`Text` の文字列の Markdown と同じく、改行を残す。
    /// 文は手で書いたものだけを渡す
    static func linkedText(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}
