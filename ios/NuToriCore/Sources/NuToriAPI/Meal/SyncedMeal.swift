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

    /// 入口。線上では、`entryMethod` の値と、文章の食事だけが持つ `sentTextId` に分かれる
    public enum EntryMethod: Sendable, Equatable {
        case captured
        case picked
        /// 文章の食事。サーバーが送った文章から作り、端末は作らない
        case written(sentTextId: UUID)

        /// サーバーの `entryMethod` の値
        public var wireName: String {
            switch self {
            case .captured: "captured"
            case .picked: "picked"
            case .written: "written"
            }
        }

        /// 線上の値から読む。知らない値と、送った文章の ID の無い文章の食事は nil
        init?(wireName: String, sentTextId: UUID?) {
            switch (wireName, sentTextId) {
            case ("captured", _): self = .captured
            case ("picked", _): self = .picked
            case ("written", let sentTextId?): self = .written(sentTextId: sentTextId)
            default: return nil
            }
        }
    }
}
