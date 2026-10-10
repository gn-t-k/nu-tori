public import Foundation

/// 返事の最初の文字を出したときに、PostHog に送る出来事（`reply_first_text_shown`）を決める。
/// 応答を待っている（まだ届いていないか、読んでいますを出している）のを見た文章だけを数え、
/// 見た時点から最初の文字が出るまでを測る。開いたときにもう返事のあった文章は数えない
public struct ReplyFirstTextWatch: Sendable {
    public init() {}

    /// タイムラインが変わるたびに渡す。`now` はそれを見た時刻
    public mutating func note(_ timeline: Timeline, at now: Date) -> [ClientUsageEvent] {
        var awaiting: Set<UUID> = []
        var shown: [UUID: Bool] = [:]
        for item in timeline.days.flatMap(\.items) {
            switch item {
            case .sentText(let bubble):
                if timeline.isUndelivered(item) || bubble.replyLine == .reading {
                    awaiting.insert(bubble.sentText.id)
                }
            case .reply(let reply) where !reply.body.isEmpty:
                shown[reply.sentTextId] = reply.isGrowing
            default:
                continue
            }
        }
        var events: [ClientUsageEvent] = []
        for (sentTextId, since) in waitingSince {
            if let watched = shown[sentTextId] {
                events.append(
                    .replyFirstTextShown(
                        sinceSent: .seconds(now.timeIntervalSince(since)), watched: watched))
                waitingSince[sentTextId] = nil
            } else if !awaiting.contains(sentTextId) {
                // 食事と読み分けた、作れなかった・回数切れ
                waitingSince[sentTextId] = nil
            }
        }
        for sentTextId in awaiting where waitingSince[sentTextId] == nil {
            waitingSince[sentTextId] = now
        }
        return events
    }

    /// 応答を待っているのを見た文章と、見始めた時刻
    private var waitingSince: [UUID: Date] = [:]
}
