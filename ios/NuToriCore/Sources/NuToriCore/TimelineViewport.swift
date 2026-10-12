/// タイムラインの見える範囲を決める。一番下についていくか、一番下へ戻すか、題と1日の丸の帯に出す日の3つの規則を持つ。
/// 画面は SwiftUI から来る知らせを出来事として渡し、返った指示を実行する
public struct TimelineViewport: Equatable, Sendable {
    public init() {}

    /// 中身が伸びたとき（返事が伸びる、送った食事のカードが足される）に、一番下についていくか。
    /// いちばん新しい日が足された描画ではついていかない。LazyVStack はまだ描いていない日の高さをほかの日の平均で見積もり、ついていくとその見積もりの端（何も無い所）へ動いて、足された日が描かれず真っ白のまま残る
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
            // 触っているあいだはついていかない
            followsEnd = false
            // 指に合わせて下げる形は、指がキーボードに届くまで下がらず、あいだに入力欄があるとふつうに動かしても届かない（#450）ので、動かし始めたら下げる
            return [.dismissKeyboard]
        case .idle:
            followsEnd = endPosition.followsWhenSettled
            // 下端ちょうどにいないと、中身が伸びてもついていけないので、使う人が入力欄の下に隠れた所で止めたら下端へ動かす（#469）。
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

    /// 写真を撮った・選んだ。遡っていても、送った食事が並ぶ一番下に戻す。食事のカードは送った時刻の位置に、あとから足されるので、足されたときも一番下についていく
    /// - Parameter isTimelineLoaded: 読み込み中は並んでいないので動かさない。取り終えたら一番下から開く
    public mutating func photoSent(isTimelineLoaded: Bool) -> [Instruction] {
        followsEnd = true
        return isTimelineLoaded ? [.scroll(to: .end, animated: false)] : []
    }

    /// 文章を送った・送り直した
    public mutating func textSent() {
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

    /// 使う人が動かして一番下から離れたら false。一番下へ戻すか、伸びる返事が無くなったら true
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
        /// 下の余白まで含めた、中身全体の下端。いちばん新しい日の下端（余白の手前）に着くと、そのあと中身が伸びてもついていけない（#467）
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
