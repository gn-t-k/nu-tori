/// 入力欄の上のチップ。押すと文面を書く欄に入れるだけで、送らない。
/// サーバーには種類を送らず、ふつうの送った文章として送る（種類は端末の利用状況の出来事にだけ載せる）
public enum TextPreset: CaseIterable, Sendable {
    case mealFeedbackSoFar
    case nextMealAdvice

    /// チップの文言。`GLOSSARY.md` の「プリセット」の名前のまま
    public var title: String {
        switch self {
        case .mealFeedbackSoFar: "ここまでの食事のフィードバック"
        case .nextMealAdvice: "次の食事のアドバイス"
        }
    }

    /// 書く欄に入れる文面
    public var text: String {
        switch self {
        case .mealFeedbackSoFar: "ここまでの食事のフィードバックをください。"
        case .nextMealAdvice: "次の食事のアドバイスをください。"
        }
    }
}
