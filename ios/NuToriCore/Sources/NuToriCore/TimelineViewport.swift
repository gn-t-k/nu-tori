public import Foundation

/// タイムラインの見える範囲を決める。位置を動かす規則と、題と1日の丸の帯に出す日の規則を持つ。
/// 画面は SwiftUI から来る知らせを出来事として渡し、返った指示を実行する。
/// 位置を動かす場面は、次の4つ。自分の操作の結果は見せ、ほかから来たもの（返事、知らせ、同期や取り込みで届いた記録）では読んでいる所から動かさない。
/// - 開く: 一番下から開く（画面が初めの位置を一番下にする）
/// - 追う: 一番下にいるあいだ、中身が伸びても（返事が伸びる、項目や日が足される）一番下に保つ。指で触れたら止める。止まったとき（アプリが動かして着いたときを含む）は、そこが一番下なら追い、違えば止める。伸びる返事が無くなったときと、送り直したときも、また追う（`followsSizeChanges`）
/// - 戻す: ユーザーがアプリの中でいちばん下に項目を足したら、遡っていても一番下へ連れていき、そこから追う（`daysChanged`）
/// - 着く: 選んだ所へ行く。日のまとめで選んだ日、帯の下の1行の知らせ、通知から開いた知らせか一番下（`dayChosen`・`landingRequested`）
public struct TimelineViewport: Equatable, Sendable {
    public init() {}

    /// 中身が伸びたときに、一番下を追うか。
    /// いちばん新しい日が足された描画では追わない。LazyVStack はまだ描いていない日の高さをほかの日の平均で見積もり、追うとその見積もりの端（何も無い所）へ動いて、足された日が描かれず真っ白のまま残る
    /// - Parameter newestDay: いま描いているタイムラインのいちばん新しい日
    public func followsSizeChanges(newestDay: CalendarDay?) -> Bool {
        followsEnd && newestDay == settledNewestDay
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
            return releasedByUser && endPosition == .underComposer
                ? [.scroll(to: .end, animated: true)] : []
        case .tracking, .decelerating, .animating:
            return []
        }
    }

    public mutating func endPositionChanged(to position: EndPosition) {
        endPosition = position
    }

    /// いちばん新しい日が、今の位置のすぐ下に描かれた。開いたときと、日が足されたときに届く
    public mutating func newestDayChanged(to newestDay: CalendarDay?) -> [Instruction] {
        // 開いたときは、初めの位置が一番下なので動かさない
        let dayAdded = settledNewestDay != nil
        settledNewestDay = newestDay
        return followsEnd && dayAdded ? [.scroll(to: .end, animated: false)] : []
    }

    public mutating func growingReplyChanged(isGrowing: Bool) {
        if !isGrowing {
            followsEnd = true
        }
    }

    /// タイムラインの日の並びが変わった
    public mutating func daysChanged(
        from old: [Timeline.Day], to new: [Timeline.Day], now: Date
    ) -> [Instruction] {
        guard Timeline.addsItemByUserAtEnd(from: old, to: new, now: now) else { return [] }
        followsEnd = true
        return [.scroll(to: .end, animated: false)]
    }

    /// 文章を送り直した・会話として送り直した
    public mutating func textResent() {
        followsEnd = true
    }

    /// 日のまとめで日を選んだ
    public func dayChosen(_ day: CalendarDay) -> [Instruction] {
        [.scroll(to: .day(day), animated: false)]
    }

    /// 答えていない知らせの1行を押した、または記録忘れの通知を押して開いた
    public func landingRequested(_ landing: Timeline.Landing) -> [Instruction] {
        switch landing {
        case .item(let itemId): [.scroll(to: .item(itemId), animated: true)]
        case .end: [.scroll(to: .end, animated: false)]
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

    /// 追うか。立てる場面と下ろす場面は、型のコメントの「追う」と「戻す」
    private var followsEnd = true
    /// 一番下に着き終えた、いちばん新しい日。日が足された描画では、まだ前の日のまま
    private var settledNewestDay: CalendarDay?
    private var endPosition = EndPosition.shown
    /// 日の位置から決めた、見えている日
    private var dayInView: CalendarDay?
}

extension TimelineViewport {
    public enum Instruction: Equatable, Sendable {
        case scroll(to: ScrollTarget, animated: Bool)
        case dismissKeyboard
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
