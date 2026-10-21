/// タイムラインに置く送った文章の吹き出し。吹き出しの下につなぐ文章の食事と、添える1行（応答待ち・作れなかった・回数切れ、受け付けなかった）を持つ
public struct SentTextBubble: Hashable, Sendable {
    public let sentText: SentText
    /// その文章からできた食事。食べた時刻（前の日を含む）にかかわらず、すべて吹き出しの下に食べた時刻の順でつなぐ
    public let meals: [MealCard]
    /// 応答の1行。応答が届いた（文章の食事、返事の最初の文字）か、まだ届いていない文章なら nil
    public let replyLine: ReplyLine?
    /// 会話として送り直す・送り直すを受け付けなかった1行。吹き出しのすぐ下に出す
    public let rejectedLine: RejectedSentTextLine?

    public init(
        sentText: SentText, meals: [MealCard], replyLine: ReplyLine?,
        rejectedLine: RejectedSentTextLine?
    ) {
        self.sentText = sentText
        self.meals = meals
        self.replyLine = replyLine
        self.rejectedLine = rejectedLine
    }

    /// 吹き出しの下の応答の1行
    public enum ReplyLine: Hashable, Sendable {
        /// 回る印と「読んでいます…」。読み分けを待つあいだと、会話と読み分けて返事の最初の文字を待つあいだ。
        /// 返事が来る場所（吹き出しの下の左の地の上）に出す
        case reading
        /// 止めた（その日の回数切れか、サブスクリプション切れ）。吹き出しの右下に、灰色の1行と「送り直す」
        case halted(SentTextStatus.HaltReason)
        /// 作れなかった。吹き出しの右下に、灰色の1行と「送り直す」
        case failed(SentTextStatus.FailureReason)

        public var text: String {
            switch self {
            case .reading: "読んでいます…"
            case .halted(.dailyLimit): "今日はもう返事を作れません"
            case .halted(.subscriptionExpired): "サブスクリプション切れのため、返事をしませんでした"
            case .failed(.retriesExhausted): "返事を作れませんでした"
            // 月の上限かは見分けず、上限は出さない（使う人にできることが無く、1日の上限と取り違える）
            case .failed(.badRequest): "今は返事を作れません。時間をおいて送り直してください"
            }
        }

        /// 「送り直す」を添える1行の理由。作れなかった・回数切れはどの理由にも添え、読んでいますには添えない（nil）
        public var resendReason: ClientUsageEvent.ReplyRegenerateReason? {
            switch self {
            case .reading: nil
            case .halted: .halted
            case .failed(let reason): .failed(reason)
            }
        }
    }
}
