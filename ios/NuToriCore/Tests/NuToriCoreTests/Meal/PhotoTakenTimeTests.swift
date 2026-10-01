import Foundation
import NuToriCore
import Testing

@Suite("写真の撮影時刻と時差の決め方")
struct PhotoTakenTimeTests {
    @Suite("撮影時刻と EXIF の時差があるとき")
    struct WithExifOffset {
        let takenTime: PhotoTakenTime

        init() throws {
            // 撮った土地は UTC-5、選んだ端末は東京
            takenTime = try PhotoTakenTime(
                exif: .takenAt(.september23(hour: 12, minute: 30), utcOffsetSeconds: -5 * 3600),
                pickedAt: Date("2026-09-30T00:00:00Z", strategy: .iso8601),
                deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("時計の時刻を EXIF の時差で絶対時刻にすること")
        func resolvesInstantWithExifOffset() throws {
            #expect(takenTime.instant == (try Date("2026-09-23T17:30:00Z", strategy: .iso8601)))
        }

        @Test("時差を EXIF の時差にすること")
        func usesExifOffset() {
            #expect(takenTime.utcOffsetSeconds == -5 * 3600)
        }
    }

    @Suite("撮影時刻があり、EXIF の時差が無いとき")
    struct WithoutExifOffset {
        let takenTime: PhotoTakenTime

        init() throws {
            takenTime = try PhotoTakenTime(
                exif: .takenAt(.september23(hour: 12, minute: 30), utcOffsetSeconds: nil),
                pickedAt: Date("2026-09-30T00:00:00Z", strategy: .iso8601),
                deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("時計の時刻を選んだときの端末のタイムゾーンで絶対時刻にすること")
        func resolvesInstantInDeviceTimeZone() throws {
            #expect(takenTime.instant == (try Date("2026-09-23T03:30:00Z", strategy: .iso8601)))
        }

        @Test("時差を選んだときの端末のタイムゾーンでのその時刻の時差にすること")
        func usesDeviceOffsetAtThatInstant() {
            #expect(takenTime.utcOffsetSeconds == 9 * 3600)
        }

        @Test("夏時間の期間なら、その時刻の夏時間の時差にすること")
        func usesDaylightSavingOffsetAtThatInstant() throws {
            let newYork = try #require(TimeZone(identifier: "America/New_York"))
            let summer = try PhotoTakenTime(
                exif: .takenAt(.september23(hour: 12, minute: 30), utcOffsetSeconds: nil),
                pickedAt: Date("2026-09-30T00:00:00Z", strategy: .iso8601),
                deviceTimeZone: newYork
            )
            let winter = try PhotoTakenTime(
                exif: .takenAt(
                    PhotoExif.WallClock(
                        year: 2026, month: 12, day: 23, hour: 12, minute: 30, second: 0),
                    utcOffsetSeconds: nil),
                pickedAt: Date("2026-12-30T00:00:00Z", strategy: .iso8601),
                deviceTimeZone: newYork
            )
            #expect(summer.utcOffsetSeconds == -4 * 3600)
            #expect(winter.utcOffsetSeconds == -5 * 3600)
        }
    }

    @Suite("撮影時刻が無いとき")
    struct WithoutCaptureTime {
        let takenTime: PhotoTakenTime
        let pickedAt: Date

        init() throws {
            pickedAt = try Date("2026-09-30T00:00:00Z", strategy: .iso8601)
            takenTime = try PhotoTakenTime(
                exif: .none,
                pickedAt: pickedAt,
                deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("選んだ時刻にすること")
        func usesPickedTime() {
            #expect(takenTime.instant == pickedAt)
        }

        @Test("時差を選んだときの端末のタイムゾーンでのその時刻の時差にすること")
        func usesDeviceOffsetAtPickedTime() {
            #expect(takenTime.utcOffsetSeconds == 9 * 3600)
        }
    }

    @Suite("撮影時刻の月日が暦に無いとき")
    struct WithImpossibleCaptureTime {
        @Test("撮影時刻が無いものとして、選んだ時刻にすること")
        func fallsBackToPickedTime() throws {
            let pickedAt = try Date("2026-09-30T00:00:00Z", strategy: .iso8601)
            let takenTime = try PhotoTakenTime(
                exif: .takenAt(
                    PhotoExif.WallClock(
                        year: 2026, month: 2, day: 30, hour: 12, minute: 30, second: 0),
                    utcOffsetSeconds: -5 * 3600),
                pickedAt: pickedAt,
                deviceTimeZone: #require(TimeZone(identifier: "Asia/Tokyo"))
            )
            #expect(takenTime.instant == pickedAt)
            #expect(takenTime.utcOffsetSeconds == 9 * 3600)
        }
    }
}

extension PhotoExif.WallClock {
    fileprivate static func september23(hour: Int, minute: Int) -> PhotoExif.WallClock {
        PhotoExif.WallClock(year: 2026, month: 9, day: 23, hour: hour, minute: minute, second: 0)
    }
}
