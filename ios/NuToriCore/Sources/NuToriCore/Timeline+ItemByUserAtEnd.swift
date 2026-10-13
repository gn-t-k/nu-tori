public import Foundation

extension Timeline {
    /// ユーザーがアプリの中で、タイムラインのいちばん下に項目（自分の記録か送った文章）を足したか。足したら、遡っていても一番下へ戻す。
    /// 返事・知らせ・受け付けなかった1行と、いちばん下でない所に入ったもの（前の文章への返事など）では戻さない。読んでいる所から引き離さないため。
    /// ヘルスケアから取り込んだ体重と、ほかの端末で足して同期で届いたものも、ここで足したものではないので戻さない。
    /// どの端末で足したかは項目から分からないので、並ぶ時刻がたった今（`justAddedWindow` の内）のものを、ここで足したものとする。
    /// 同じ時刻に並ぶ自分のものは ID の順になり、足したものが最後に来るとは限らない（一度に選んだ写真が、いくつかの食事になって1つずつ足されるとき）。
    /// そのあいだに足されたものも、いちばん下に足されたとする
    public static func addsItemByUserAtEnd(from old: [Day], to new: [Day], now: Date) -> Bool {
        // 足されたものより下にある、前からの項目が並ぶ時刻
        var tiedAt: Date?
        for item in new.reversed().lazy.flatMap({ $0.items.reversed() }) {
            // 前からある項目は下のほうにあるので、下から探す
            let isAdded = !old.reversed().contains {
                $0.items.reversed().contains { $0.id == item.id }
            }
            guard let placedAt = item.placedAtByUser else {
                if isAdded { continue }
                return false
            }
            if isAdded {
                return (tiedAt == nil || tiedAt == placedAt)
                    && (0...justAddedWindow).contains(now.timeIntervalSince(placedAt))
            }
            if let tiedAt, tiedAt != placedAt {
                return false
            }
            tiedAt = placedAt
        }
        return false
    }

    /// 足す操作から項目が並ぶまでの間（写真の読み込みと縮小）より長く、ほかの端末で足したものが同期で届くまでの間より短くとる
    private static let justAddedWindow: TimeInterval = 60
}

extension Timeline.Item {
    /// ユーザーがアプリの中で足す項目が並ぶ時刻。ほかは nil
    fileprivate var placedAtByUser: Date? {
        switch self {
        case .weightRecord(let record):
            switch record.inputSource {
            case .manual: record.instant
            case .imported: nil
            }
        case .meal(let card): card.meal.sentAt
        case .sentText(let bubble): bubble.sentText.sentAt
        case .rejectedWeightLine, .rejectedMealLine, .rejectedSentTextLine, .notice, .reply: nil
        }
    }
}
