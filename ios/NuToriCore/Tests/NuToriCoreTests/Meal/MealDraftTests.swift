import Foundation
import NuToriCore
import Testing

@Suite("食事の下書きの決め方")
struct MealDraftTests {
    @Suite("撮った食事")
    struct Captured {
        let draft: MealDraft
        let photoId = UUID()

        init() throws {
            draft = try MealDraft.captured(
                photoId: photoId,
                takenAt: Date("2026-09-23T10:40:00Z", strategy: .iso8601),
                sentAt: Date("2026-09-23T10:41:00Z", strategy: .iso8601),
                deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("食事の時刻を撮った時刻にすること")
        func eatenAtIsTakenTime() throws {
            #expect(draft.eatenAt == (try Date("2026-09-23T10:40:00Z", strategy: .iso8601)))
        }

        @Test("食事の時差を端末のタイムゾーンでのその時刻の時差にすること")
        func eatenOffsetIsDeviceOffset() {
            #expect(draft.eatenUtcOffsetSeconds == 9 * 3600)
        }

        @Test("送った時刻を送る操作をした時刻にし、送ったときのタイムゾーンを端末の IANA 名にすること")
        func sentAtAndTimeZone() throws {
            #expect(draft.sentAt == (try Date("2026-09-23T10:41:00Z", strategy: .iso8601)))
            #expect(draft.sentTimeZoneIdentifier == "Asia/Tokyo")
        }

        @Test("入口を撮ったにし、写真を1枚にすること")
        func entryAndPhotos() {
            #expect(draft.entry == .captured)
            #expect(draft.photoIds == [photoId])
        }
    }

    @Suite("撮っておいた写真を選んだとき")
    struct Picked {
        @Suite("撮影時刻の差が 30 分以内の写真だけのとき")
        struct WithinThirtyMinutes {
            let photos: [PickedPhoto]
            let drafts: [MealDraft]

            init() throws {
                // 隣との差が 30 分ちょうど、25 分。最初と最後の差は 55 分
                photos = try [
                    PickedPhoto.taken(at: "2026-09-23T10:55:00Z"),
                    PickedPhoto.taken(at: "2026-09-23T10:00:00Z"),
                    PickedPhoto.taken(at: "2026-09-23T10:30:00Z"),
                ]
                drafts = try MealDraft.picked(
                    photos,
                    sentAt: Date("2026-09-30T03:00:00Z", strategy: .iso8601),
                    deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
                )
            }

            @Test("1つの食事にまとめ、写真を撮影時刻の順に並べること")
            func groupsIntoOneMealInTakenOrder() {
                #expect(drafts.count == 1)
                #expect(drafts.first?.photoIds == [photos[1].id, photos[2].id, photos[0].id])
            }

            @Test("入口を写真を選んだにすること")
            func entryIsPicked() {
                #expect(drafts.first?.entry == .picked)
            }

            @Test("食事の時刻をいちばん早い写真の時刻にすること")
            func eatenAtIsEarliestPhoto() throws {
                #expect(
                    drafts.first?.eatenAt == (try Date("2026-09-23T10:00:00Z", strategy: .iso8601)))
            }
        }

        @Suite("隣との差が 30 分を超えるとき")
        struct OverThirtyMinutes {
            let photos: [PickedPhoto]
            let drafts: [MealDraft]

            init() throws {
                // 30 分と 1 秒あく
                photos = try [
                    PickedPhoto.taken(at: "2026-09-23T10:00:00Z"),
                    PickedPhoto.taken(at: "2026-09-23T10:30:01Z"),
                    PickedPhoto.taken(at: "2026-09-23T10:40:00Z"),
                ]
                drafts = try MealDraft.picked(
                    photos,
                    sentAt: Date("2026-09-30T03:00:00Z", strategy: .iso8601),
                    deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
                )
            }

            @Test("別の食事に分け、食事を時刻の順に並べること")
            func splitsIntoMeals() {
                #expect(drafts.map(\.photoIds) == [[photos[0].id], [photos[1].id, photos[2].id]])
            }
        }

        @Suite("タイムゾーンが違う写真が混じるとき")
        struct MixedOffsets {
            @Test("時計の時刻でなく絶対時刻で比べること")
            func comparesAbsoluteInstants() throws {
                // 時計の読みは 10:00 と 10:10 だが、絶対時刻は 2 時間 10 分ちがう
                let photos = [
                    PickedPhoto(
                        id: UUID(),
                        takenTime: PhotoTakenTime(
                            instant: try Date("2026-09-23T01:00:00Z", strategy: .iso8601),
                            utcOffsetSeconds: 9 * 3600)),
                    PickedPhoto(
                        id: UUID(),
                        takenTime: PhotoTakenTime(
                            instant: try Date("2026-09-23T10:10:00Z", strategy: .iso8601),
                            utcOffsetSeconds: 0)),
                ]
                let drafts = try MealDraft.picked(
                    photos,
                    sentAt: Date("2026-09-30T03:00:00Z", strategy: .iso8601),
                    deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
                )
                #expect(drafts.count == 2)
            }
        }

        @Suite("近い写真が5枚以上あるとき")
        struct FiveOrMoreClose {
            @Test("5枚は、時刻の順に4枚と1枚の食事に分けること")
            func splitsFiveIntoFourAndOne() throws {
                let photos = try (0..<5).map { try PickedPhoto.taken(minutesAfterNoon: $0) }
                let drafts = try MealDraft.picked(
                    photos, sentAt: Date(timeIntervalSince1970: 0), deviceTimeZone: .gmt)
                #expect(
                    drafts.map(\.photoIds)
                        == [photos[0..<4].map(\.id), [photos[4].id]])
            }

            @Test("4枚は、分けずに1つの食事にすること")
            func keepsFourTogether() throws {
                let photos = try (0..<4).map { try PickedPhoto.taken(minutesAfterNoon: $0) }
                let drafts = try MealDraft.picked(
                    photos, sentAt: Date(timeIntervalSince1970: 0), deviceTimeZone: .gmt)
                #expect(drafts.count == 1)
            }

            @Test("10枚は、4枚と4枚と2枚の食事に分け、あとの食事の時刻をその食事のいちばん早い写真にすること")
            func splitsTenIntoFourFourTwo() throws {
                let photos = try (0..<10).map { try PickedPhoto.taken(minutesAfterNoon: $0) }
                let drafts = try MealDraft.picked(
                    photos, sentAt: Date(timeIntervalSince1970: 0), deviceTimeZone: .gmt)
                #expect(drafts.map(\.photoIds.count) == [4, 4, 2])
                #expect(drafts[1].eatenAt == photos[4].takenTime.instant)
                #expect(drafts[2].eatenAt == photos[8].takenTime.instant)
            }
        }

        @Suite("食事の時差")
        struct EatenOffset {
            @Test("いちばん早い写真の時差にすること")
            func usesEarliestPhotoOffset() throws {
                let earliest = PickedPhoto(
                    id: UUID(),
                    takenTime: PhotoTakenTime(
                        instant: try Date("2026-09-23T10:00:00Z", strategy: .iso8601),
                        utcOffsetSeconds: -5 * 3600))
                let later = PickedPhoto(
                    id: UUID(),
                    takenTime: PhotoTakenTime(
                        instant: try Date("2026-09-23T10:10:00Z", strategy: .iso8601),
                        utcOffsetSeconds: 9 * 3600))
                let drafts = try MealDraft.picked(
                    [later, earliest], sentAt: Date(timeIntervalSince1970: 0),
                    deviceTimeZone: .gmt)
                #expect(drafts.first?.eatenUtcOffsetSeconds == -5 * 3600)
            }
        }

        @Suite("送った時刻とタイムゾーン")
        struct Sent {
            @Test("1回に選んでできた食事すべてで、同じ送った時刻と端末の IANA 名にすること")
            func sharesSentAtAndTimeZone() throws {
                let photos = try [
                    PickedPhoto.taken(at: "2026-09-23T10:00:00Z"),
                    PickedPhoto.taken(at: "2026-09-24T10:00:00Z"),
                ]
                let sentAt = try Date("2026-09-30T03:00:00Z", strategy: .iso8601)
                let drafts = try MealDraft.picked(
                    photos, sentAt: sentAt,
                    deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo")))
                #expect(drafts.map(\.sentAt) == [sentAt, sentAt])
                #expect(drafts.map(\.sentTimeZoneIdentifier) == ["Asia/Tokyo", "Asia/Tokyo"])
            }
        }

        @Suite("1回に選べる枚数")
        struct SelectionLimit {
            @Test("10枚までを受け付けること")
            func acceptsTen() throws {
                let photos = try (0..<10).map { try PickedPhoto.taken(minutesAfterNoon: $0) }
                #expect(
                    throws: Never.self,
                    performing: {
                        try MealDraft.picked(
                            photos, sentAt: Date(timeIntervalSince1970: 0), deviceTimeZone: .gmt)
                    })
            }

            @Test("11枚は受け付けないこと")
            func rejectsEleven() throws {
                let photos = try (0..<11).map { try PickedPhoto.taken(minutesAfterNoon: $0) }
                #expect(throws: MealDraft.PickError.tooManyPhotos(count: 11)) {
                    try MealDraft.picked(
                        photos, sentAt: Date(timeIntervalSince1970: 0), deviceTimeZone: .gmt)
                }
            }

            @Test("上限を 10 枚として公開すること")
            func exposesLimit() {
                #expect(MealDraft.maxPhotosPerSelection == 10)
            }
        }
    }
}

extension PickedPhoto {
    /// at は ISO 8601 の時刻（"2026-09-23T10:00:00Z"）。時差は 0
    fileprivate static func taken(at instant: String) throws -> PickedPhoto {
        PickedPhoto(
            id: UUID(),
            takenTime: PhotoTakenTime(
                instant: try Date(instant, strategy: .iso8601), utcOffsetSeconds: 0))
    }

    fileprivate static func taken(minutesAfterNoon minutes: Int) throws -> PickedPhoto {
        PickedPhoto(
            id: UUID(),
            takenTime: PhotoTakenTime(
                instant: try Date("2026-09-23T12:00:00Z", strategy: .iso8601)
                    .addingTimeInterval(Double(minutes) * 60),
                utcOffsetSeconds: 0))
    }
}
