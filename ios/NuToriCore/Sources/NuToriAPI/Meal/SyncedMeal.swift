public import Foundation

/// 食事。作る書き込みで送る形と、取りに行く変更で届く形が同じ（版を持たない）
public struct SyncedMeal: Sendable, Equatable {
    public let id: UUID
    public let eatenAt: Date
    /// 食事の時刻の UTC との時差の秒
    public let eatenUtcOffsetSeconds: Int
    public let sentAt: Date
    public let sentTimeZone: TimeZone
    public let entryMethod: EntryMethod
    /// 並びが写真の並び順
    public let photoIds: [UUID]

    public init(
        id: UUID,
        eatenAt: Date,
        eatenUtcOffsetSeconds: Int,
        sentAt: Date,
        sentTimeZone: TimeZone,
        entryMethod: EntryMethod,
        photoIds: [UUID]
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.eatenUtcOffsetSeconds = eatenUtcOffsetSeconds
        self.sentAt = sentAt
        self.sentTimeZone = sentTimeZone
        self.entryMethod = entryMethod
        self.photoIds = photoIds
    }

    /// サーバーの `entryMethod` の値
    public enum EntryMethod: String, Sendable, Equatable {
        case captured
        case picked
    }
}
