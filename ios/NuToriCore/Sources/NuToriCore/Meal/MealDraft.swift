public import Foundation

/// 端末が決めた、送る前の食事。時刻・時差・入口・写真の並びを持つ
public struct MealDraft: Hashable, Sendable {
    /// 食事の時刻
    public let eatenAt: Date
    /// 食事の時刻の UTC との時差。IANA 名でないのは、写真には時差しか残らないことがあるため
    public let eatenUtcOffsetSeconds: Int
    public let sentAt: Date
    /// 送ったときの端末のタイムゾーン。サーバーには IANA 名で送る
    public let sentTimeZone: TimeZone
    public let entry: Entry
    /// 撮影時刻の順
    public let photoIds: [UUID]

    /// rawValue は、キャッシュと送り待ちに保存する書き方。変えると、送り待ちの置き場の移行が要る
    public enum Entry: String, Hashable, Sendable {
        case captured
        case picked
    }

    public enum PickError: Error, Hashable, Sendable {
        case tooManyPhotos(count: Int)
    }

    /// 1回に選べる写真の枚数
    public static let maxPhotosPerSelection = 10

    /// 撮った写真は、1枚で1つの食事にする。食事の時刻は撮った時刻、送った時刻は送る操作をした時刻
    public static func captured(
        photoId: UUID,
        takenAt: Date,
        sentAt: Date,
        deviceTimeZone: TimeZone
    ) -> MealDraft {
        MealDraft(
            eatenTime: PhotoTakenTime(instant: takenAt, deviceTimeZone: deviceTimeZone),
            sentAt: sentAt,
            sentTimeZone: deviceTimeZone,
            entry: .captured,
            photoIds: [photoId]
        )
    }

    /// 選んだ写真を、近い時刻ごとの食事にまとめる。できた食事は、どれも同じ送った時刻を持つ
    public static func picked(
        _ photos: [PickedPhoto],
        sentAt: Date,
        deviceTimeZone: TimeZone
    ) throws(PickError) -> [MealDraft] {
        guard photos.count <= maxPhotosPerSelection else {
            throw .tooManyPhotos(count: photos.count)
        }
        return Self.meals(from: photos).map { mealPhotos in
            MealDraft(
                eatenTime: mealPhotos[0].takenTime,
                sentAt: sentAt,
                sentTimeZone: deviceTimeZone,
                entry: .picked,
                photoIds: mealPhotos.map(\.id)
            )
        }
    }

    private static let groupingInterval: TimeInterval = 30 * 60
    private static let maxPhotosPerMeal = 4

    private init(
        eatenTime: PhotoTakenTime,
        sentAt: Date,
        sentTimeZone: TimeZone,
        entry: Entry,
        photoIds: [UUID]
    ) {
        eatenAt = eatenTime.instant
        eatenUtcOffsetSeconds = eatenTime.utcOffsetSeconds
        self.sentAt = sentAt
        self.sentTimeZone = sentTimeZone
        self.entry = entry
        self.photoIds = photoIds
    }

    /// 撮影時刻の順に並べた写真を、食事ごとの組にする
    private static func meals(from photos: [PickedPhoto]) -> [[PickedPhoto]] {
        // 同じ時刻の写真は、渡された順を保つ
        let sorted = photos.enumerated()
            .sorted {
                ($0.element.takenTime.instant, $0.offset) < (
                    $1.element.takenTime.instant, $1.offset
                )
            }
            .map(\.element)
        var groups: [[PickedPhoto]] = []
        for photo in sorted {
            if let last = groups.last?.last,
                photo.takenTime.instant.timeIntervalSince(last.takenTime.instant)
                    <= groupingInterval
            {
                groups[groups.count - 1].append(photo)
            } else {
                groups.append([photo])
            }
        }
        return groups.flatMap { group in
            stride(from: 0, to: group.count, by: maxPhotosPerMeal).map {
                Array(group[$0..<min($0 + maxPhotosPerMeal, group.count)])
            }
        }
    }
}
