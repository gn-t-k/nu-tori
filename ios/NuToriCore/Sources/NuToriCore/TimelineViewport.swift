public import Foundation

/// タイムラインの見える範囲を決める。並べる日の規則と、位置を動かす規則と、題と1日の丸の帯に出す日の規則を持つ。
/// 画面は SwiftUI から来る知らせを出来事として渡し、返った指示を実行する。
/// 並べるのは新しいほうの日だけにして、遡ったら古い日を足す（`listedDays`）。全部の日を遅れて読む並び（LazyVStack）にすると、まだ描いていない日の高さが見積もりになり、日の高さがばらつくと、一番下がその見積もりの端（何も無い所）になって真っ白のまま残る。遅れて読まずに全部を並べると、記録が増えるほど開くのが遅くなる
/// 位置を動かす場面は、次の5つ。自分の操作の結果は見せ、ほかから来たもの（返事、知らせ、同期や取り込みで届いた記録）では読んでいる所から動かさない。
/// - 開く: 一番下から開く（画面が初めの位置を一番下にする）
/// - 追う: 一番下にいるあいだ、中身が伸びても（返事が伸びる、項目や日が足される）一番下に保つ。指で触れたら止める。止まったとき（アプリが動かして着いたときを含む）は、そこが一番下なら追い、違えば止める。伸びる返事が無くなったときと、送り直したときも、また追う（`followsSizeChanges`）
/// - 戻す: ユーザーがアプリの中でいちばん下に項目を足したら、遡っていても一番下へ連れていき、そこから追う（`daysChanged`）
/// - 着く: 選んだ所へ行く。日のまとめで選んだ日、帯の下の1行の知らせ、通知から開いた知らせか一番下（`dayChosen`・`landingRequested`）。並べていない日なら、その日まで並べてから行く
/// - 古い日を足す: 並べたいちばん古い日の上端まで遡って止まったら、その前の日を足し、見ていた日を上端に置き直す（`listOlderDays`）
public struct TimelineViewport: Equatable, Sendable {
    public init() {}

    /// 並べる日。開いたときは、新しいほうから1回に並べる分（`oldestDay(ofBatchBefore:in:)`）。そこから古いほうへは、遡ったときと、古い日へ着くときに足す
    public func listedDays(of days: [Timeline.Day]) -> ArraySlice<Timeline.Day> {
        let oldest = oldestListedDay ?? Self.oldestDay(ofBatchBefore: nil, in: days)
        return days.drop { day in oldest.map { day.day < $0 } ?? false }
    }

    /// 中身が伸びたときに、一番下を追うか
    public var followsSizeChanges: Bool {
        followsEnd
    }

    /// 題と1日の丸の帯に出す日。日の位置は遅れて届き、開いた直後に下端へ動いたあとの位置が届かないことがあるので（#442）、一番下にいるかは下端の位置から決める
    /// - Parameter newestDay: いま描いているタイムラインのいちばん新しい日
    public func shownDay(newestDay: CalendarDay?) -> CalendarDay? {
        endPosition == .shown ? newestDay : dayInView ?? newestDay
    }

    // MARK: 出来事

    public mutating func scrollPhaseChanged(
        from oldPhase: ScrollPhase, to phase: ScrollPhase
    ) -> [Instruction] {
        switch phase {
        case .interacting:
            // 触っているあいだは追わない
            followsEnd = false
            // 指に合わせて下げる形は、指がキーボードに届くまで下がらず、あいだに入力欄があるとふつうに動かしても届かない（#450）ので、動かし始めたら下げる
            return [.dismissKeyboard]
        case .idle:
            followsEnd = endPosition.followsWhenSettled
            // 下端ちょうどにいないと、中身が伸びても追えないので、使う人が入力欄の下に隠れた所で止めたら下端へ動かす（#469）。
            // アプリが動かして止まったとき（知らせのカードへ着いた、ここで下端へ動かした）は、着いた所に置く
            let releasedByUser = oldPhase == .interacting || oldPhase == .decelerating
            let stoppedUnderComposer = releasedByUser && endPosition == .underComposer
            // 何で動いたか（指、ステータスバーを押した、VoiceOver で送った）は問わず、動いて上端で止まったら古い日を足す。
            // 足さないのは、開いたときに届く「止まっていた → 止まった」だけ。まだ並べ終えておらず、上端にいるように見えることがある
            let stoppedAtStart = oldPhase != .idle && isAtStart
            return (stoppedUnderComposer ? [.scroll(to: .end, animated: true)] : [])
                + (stoppedAtStart ? [.listOlderDays] : [])
        case .tracking, .decelerating, .animating:
            return []
        }
    }

    public mutating func endPositionChanged(to position: EndPosition) {
        endPosition = position
    }

    /// 並べたいちばん古い日の上端が、見えている所の上端にあるかが変わった
    public mutating func startReachedChanged(isAtStart: Bool) {
        self.isAtStart = isAtStart
    }

    /// 並べたいちばん古い日の前の日を足す。足した分だけ中身が下へずれるので、見ていた日を上端に置き直す。足す日が無ければ何もしない
    public mutating func listOlderDays(of days: [Timeline.Day]) -> [Instruction] {
        guard let listedOldest = listedDays(of: days).first?.day,
            let oldest = Self.oldestDay(ofBatchBefore: listedOldest, in: days)
        else { return [] }
        oldestListedDay = oldest
        return [.scroll(to: .day(listedOldest), animated: false)]
    }

    public mutating func growingReplyChanged(isGrowing: Bool) {
        if !isGrowing {
            followsEnd = true
        }
    }

    /// 開いて日の並びが届いた（`old` と `new` が同じ）、または、タイムラインの日の並びが変わった
    public mutating func daysChanged(
        from old: [Timeline.Day], to new: [Timeline.Day], now: Date
    ) -> [Instruction] {
        // 一番下にいるあいだは、新しい並びで数え直す（開いたあとに同期で届いた古い日を並べ、遡って足した日を片づける）。上の日が出入りしても、一番下からは見えない。
        // 遡っているあいだは、並べていた日のままにする。上の日が出入りすると、読んでいる所がずれる
        let isAtEnd = followsEnd && endPosition != .offscreen
        oldestListedDay =
            isAtEnd
            ? Self.oldestDay(ofBatchBefore: nil, in: new) : listedDays(of: old).first?.day
        guard Timeline.addsItemByUserAtEnd(from: old, to: new, now: now) else { return [] }
        followsEnd = true
        return [.scroll(to: .end, animated: false)]
    }

    /// 文章を送り直した・会話として送り直した
    public mutating func textResent() {
        followsEnd = true
    }

    /// 日のまとめで日を選んだ
    public mutating func dayChosen(_ day: CalendarDay, in days: [Timeline.Day]) -> [Instruction] {
        list(day, in: days)
        return [.scroll(to: .day(day), animated: false)]
    }

    /// 答えていない知らせの1行を押した、または記録忘れの通知を押して開いた
    public mutating func landingRequested(
        _ landing: Timeline.Landing, in days: [Timeline.Day]
    ) -> [Instruction] {
        switch landing {
        case .item(let itemId):
            if let day = days.first(where: { $0.items.contains { $0.id == itemId } }) {
                list(day.day, in: days)
            }
            return [.scroll(to: .item(itemId), animated: true)]
        case .end:
            return [.scroll(to: .end, animated: false)]
        }
    }

    /// - Parameters:
    ///   - positions: 描かれている日の区切りの上端。見えている所の上端からの距離
    ///   - newestDay: いま描いているタイムラインのいちばん新しい日
    ///   - viewportHeight: 見えている所の高さ
    public mutating func dayPositionsChanged(
        _ positions: [DayPosition], newestDay: CalendarDay?, viewportHeight: Double
    ) {
        // 開いた位置は下端。いちばん新しい日が少し上にはみ出していても、その日を題にする
        let newestStillVisible = -40.0
        let topEdge = 8.0
        if let newestDay,
            let newest = positions.first(where: { $0.day == newestDay }),
            newest.minY < viewportHeight, newest.minY > newestStillVisible
        {
            dayInView = newestDay
            return
        }
        // 遡っているときは、上端にかかっている日
        let atTop = positions.filter { $0.minY <= topEdge }.max { $0.minY < $1.minY }
        dayInView = atTop?.day ?? positions.min { $0.minY < $1.minY }?.day
    }

    // MARK: 内部

    /// `day` の前の日から古いほうへ、1回に並べる分を数えた、いちばん古い日。`day` が nil なら、いちばん新しい日から数える。数える日が無ければ nil
    private static func oldestDay(
        ofBatchBefore day: CalendarDay?, in days: [Timeline.Day]
    ) -> CalendarDay? {
        // 1回に並べる日の、項目の数の目安。画面の数倍になり、開くのが遅くならない数
        let batchItemCount = 30
        // 1回に並べる日の数の上限。記録の無い日が続いても、区切りだけで画面を超える
        let batchDayCount = 30
        let olderDays = days.prefix { candidate in day.map { candidate.day < $0 } ?? true }
        var itemCount = 0
        var oldest: CalendarDay?
        for (countedDays, olderDay) in olderDays.reversed().enumerated() {
            guard itemCount < batchItemCount, countedDays < batchDayCount else { break }
            itemCount += olderDay.items.count
            oldest = olderDay.day
        }
        return oldest
    }

    /// その日が並んでいなければ、その日まで並べる
    private mutating func list(_ day: CalendarDay, in days: [Timeline.Day]) {
        guard let listedOldest = listedDays(of: days).first?.day else { return }
        oldestListedDay = min(listedOldest, day)
    }

    /// 並べたいちばん古い日。開いて日の並びが届くまでは決めず、そのつど数える
    private var oldestListedDay: CalendarDay?
    private var isAtStart = false
    /// 追うか。立てる場面と下ろす場面は、型のコメントの「追う」と「戻す」
    private var followsEnd = true
    private var endPosition = EndPosition.shown
    /// 日の位置から決めた、見えている日
    private var dayInView: CalendarDay?
}

extension TimelineViewport {
    public enum Instruction: Equatable, Sendable {
        case scroll(to: ScrollTarget, animated: Bool)
        case dismissKeyboard
        /// 並べたいちばん古い日の前の日を足す。足す日は、そのときの日の並びから `listOlderDays` が決める
        case listOlderDays
    }

    public enum ScrollTarget: Equatable, Sendable {
        /// 下の余白まで含めた、中身全体の下端。いちばん新しい日の下端（余白の手前）に着くと、そのあと中身が伸びても追えない（#467）
        case end
        /// その日の区切りの上端
        case day(CalendarDay)
        /// そのカードの上端
        case item(Timeline.Item.ID)
    }

    public struct DayPosition: Equatable, Sendable {
        public let day: CalendarDay
        public let minY: Double

        public init(day: CalendarDay, minY: Double) {
            self.day = day
            self.minY = minY
        }
    }

    /// SwiftUI の ScrollPhase の写し
    public enum ScrollPhase: Equatable, Sendable {
        case idle
        case tracking
        case interacting
        case decelerating
        case animating
    }
}
