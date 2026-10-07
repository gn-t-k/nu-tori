public import Foundation

/// 食事。端末が振った ID と、送る前に決めた時刻・時差・入口・写真の並びを持つ。推定の状態と料理は別の種類
public struct Meal: Hashable, Sendable {
    public let id: UUID
    /// 撮った時刻
    public let eatenAt: Date
    /// 食事の時刻の UTC との時差。IANA 名でないのは、写真には時差しか残らないことがあるため
    public let eatenUtcOffsetSeconds: Int
    public let sentAt: Date
    public let sentTimeZone: TimeZone
    public let entry: MealDraft.Entry
    /// 写真の並び順
    public let photoIds: [UUID]

    public init(
        id: UUID,
        eatenAt: Date,
        eatenUtcOffsetSeconds: Int,
        sentAt: Date,
        sentTimeZone: TimeZone,
        entry: MealDraft.Entry,
        photoIds: [UUID]
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.eatenUtcOffsetSeconds = eatenUtcOffsetSeconds
        self.sentAt = sentAt
        self.sentTimeZone = sentTimeZone
        self.entry = entry
        self.photoIds = photoIds
    }

    public init(id: UUID, draft: MealDraft) {
        self.init(
            id: id,
            eatenAt: draft.eatenAt,
            eatenUtcOffsetSeconds: draft.eatenUtcOffsetSeconds,
            sentAt: draft.sentAt,
            sentTimeZone: draft.sentTimeZone,
            entry: draft.entry,
            photoIds: draft.photoIds
        )
    }

    /// 食事の日。1日の丸と日のまとめに入れる日で、撮った時刻と食事の時差で決める
    public var day: CalendarDay {
        CalendarDay(containing: eatenAt, utcOffsetSeconds: eatenUtcOffsetSeconds)
    }

    /// タイムラインでカードを置く日。送った時刻と、送ったときのタイムゾーンで決める
    public var cardDay: CalendarDay {
        CalendarDay(containing: sentAt, in: sentTimeZone)
    }

    /// 食事の時差だけを持つタイムゾーン。時刻を直す欄は、撮った時刻をこの時計で見せ、直した値もこの時計の時刻として受け取る
    public var eatenTimeZone: TimeZone {
        // 時差は秒で持ち、ありうる幅（±18 時間）の中なので作れる
        TimeZone(secondsFromGMT: eatenUtcOffsetSeconds) ?? .gmt
    }

    /// 撮った時刻に食事の時差を足した時計の時刻
    public var eatenClockTime: ClockTime {
        ClockTime(containing: eatenAt, utcOffsetSeconds: eatenUtcOffsetSeconds)
    }
}
