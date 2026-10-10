public import Foundation

/// 送った文章。端末が振った ID と、送ったときの本文・時刻・タイムゾーンを持ち、作ったあと変わらない。
/// 読み分けの結果と応答の状態は別の種類（送った文章の状態）
public struct SentText: Hashable, Sendable {
    public let id: UUID
    public let body: String
    /// 送る操作をした時刻
    public let sentAt: Date
    /// 送ったときのタイムゾーン
    public let timeZone: TimeZone

    public init(id: UUID, body: String, sentAt: Date, timeZone: TimeZone) {
        self.id = id
        self.body = body
        self.sentAt = sentAt
        self.timeZone = timeZone
    }

    /// 送る本文。前後の空白を除いた本文にし、受け付ける範囲の外（空白だけ、長すぎる）なら nil。
    /// 字は、サーバーと同じ数になるよう Unicode のコードポイントで数える
    static func acceptedBody(typed: String) -> String? {
        let body = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return AcceptedRange.sentTextBodyTrimmedLength.bounds.contains(
            Double(body.unicodeScalars.count)) ? body : nil
    }
}
