/// 目標の設定の4つの要求の結果。断る応答（400・422）は不具合のときだけ届く
public enum GoalSetupResult<Answer: Sendable & Equatable>: Sendable, Equatable {
    case answered(Answer)
    /// 400（形の誤り）。`code` はサーバーが断った理由
    case badRequest(code: String)
    /// 422（形は合っているが値を受け付けない）
    case unprocessable(code: String)
    case sessionExpired
    case rateLimited
}
