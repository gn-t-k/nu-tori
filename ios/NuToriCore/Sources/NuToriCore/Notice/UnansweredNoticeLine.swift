/// 帯の下に1行で示す、答えていない知らせ。
/// 画面は、このうちカードが上へ流れて見えないものだけを出す（`UnansweredNoticeLineVisibility`）
public enum UnansweredNoticeLine: Hashable, Sendable {
    /// 今日の答えていない体重の知らせ
    case missedWeightRecord(NoticeCard)
    /// 答えていない、目標を立てる知らせ（「目標を立てる ›」）。目標が決まると答えた形になり、並ばなくなる
    case goalSetup(Notice)

    public var notice: Notice {
        switch self {
        case .missedWeightRecord(let card): card.notice
        case .goalSetup(let notice): notice
        }
    }

    /// 答えていない知らせの1行を、出した時刻の古い順に並べる
    static func lines(weightNoticeAwaitingAnswer: NoticeCard?, notices: [Notice])
        -> [UnansweredNoticeLine]
    {
        let goalSetup = notices.first { $0.kind == .goalSetup && $0.response == nil }
        let lines =
            [weightNoticeAwaitingAnswer.map(UnansweredNoticeLine.missedWeightRecord)]
            + [goalSetup.map(UnansweredNoticeLine.goalSetup)]
        return lines.compactMap(\.self).sorted { $0.notice.issuedAt < $1.notice.issuedAt }
    }
}
