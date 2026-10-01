import NuToriCore
import Testing

@Suite("写真の EXIF の撮影時刻と時差の読み方")
struct PhotoExifTests {
    @Suite("撮影時刻と時差があるとき")
    struct WithOffset {
        @Test("時計の読みと、時差を秒にした値にすること")
        func readsBoth() {
            let exif = PhotoExif(
                dateTimeOriginal: "2026:09:24 19:40:12", offsetTimeOriginal: "+09:00")

            #expect(
                exif
                    == .takenAt(
                        PhotoExif.WallClock(
                            year: 2026, month: 9, day: 24, hour: 19, minute: 40, second: 12),
                        utcOffsetSeconds: 9 * 3600))
        }

        static let signedOffsets: [(text: String, seconds: Int)] = [
            ("-07:00", -25_200),
            ("+05:30", 19_800),
            ("-03:30", -12_600),
        ]

        @Test("西の時差と、分のある時差を読むこと", arguments: signedOffsets)
        func readsSignedOffsets(offset: (text: String, seconds: Int)) {
            let exif = PhotoExif(
                dateTimeOriginal: "2026:09:24 19:40:12", offsetTimeOriginal: offset.text)

            guard case .takenAt(_, let utcOffsetSeconds) = exif else {
                Issue.record("撮影時刻が読めていない")
                return
            }
            #expect(utcOffsetSeconds == offset.seconds)
        }
    }

    @Suite("時差が無い、または読めないとき")
    struct WithoutOffset {
        static let unreadableOffsets: [String?] = [nil, "", "JST", "+9", "+09:00:00"]

        @Test("撮影時刻だけを読むこと", arguments: unreadableOffsets)
        func readsOnlyWallClock(offset: String?) {
            let exif = PhotoExif(dateTimeOriginal: "2026:09:24 07:05:00", offsetTimeOriginal: offset)

            #expect(
                exif
                    == .takenAt(
                        PhotoExif.WallClock(
                            year: 2026, month: 9, day: 24, hour: 7, minute: 5, second: 0),
                        utcOffsetSeconds: nil))
        }
    }

    @Suite("撮影時刻が無い、または読めないとき")
    struct WithoutDateTime {
        static let unreadableDateTimes: [String?] = [
            nil, "", "2026-09-24 19:40:12", "2026:09:24", "    :  :     :  :  ", "2026:09:24 19:40",
        ]

        @Test("時差があっても、撮影時刻が無いものにすること", arguments: unreadableDateTimes)
        func isNone(dateTime: String?) {
            #expect(
                PhotoExif(dateTimeOriginal: dateTime, offsetTimeOriginal: "+09:00") == .none)
        }
    }
}
