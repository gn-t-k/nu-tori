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
                        utcOffsetSeconds: 32_400))
        }

        @Test("西の時差は、負の秒にすること")
        func readsWesternOffset() {
            let exif = PhotoExif(
                dateTimeOriginal: "2026:09:24 19:40:12", offsetTimeOriginal: "-07:00")

            #expect(exif.utcOffsetSeconds == -25_200)
        }

        @Test("分のある時差は、分も秒にすること")
        func readsMinutes() {
            let exif = PhotoExif(
                dateTimeOriginal: "2026:09:24 19:40:12", offsetTimeOriginal: "+05:30")

            #expect(exif.utcOffsetSeconds == 19_800)
        }
    }

    @Suite("時差が無いとき")
    struct WithoutOffset {
        @Test("撮影時刻だけを読むこと")
        func readsOnlyWallClock() {
            let exif = PhotoExif(dateTimeOriginal: "2026:09:24 07:05:00", offsetTimeOriginal: nil)

            #expect(
                exif
                    == .takenAt(
                        PhotoExif.WallClock(
                            year: 2026, month: 9, day: 24, hour: 7, minute: 5, second: 0),
                        utcOffsetSeconds: nil))
        }
    }

    @Suite("時差の形が違うとき")
    struct UnreadableOffset {
        @Test("時差を無いものにし、撮影時刻は読むこと")
        func dropsOnlyOffset() {
            let dateTime = "2026:09:24 07:05:00"
            let withoutOffset = PhotoExif(dateTimeOriginal: dateTime, offsetTimeOriginal: nil)

            // 名前で書いた、桁が足りない、秒まである
            #expect(
                PhotoExif(dateTimeOriginal: dateTime, offsetTimeOriginal: "JST") == withoutOffset)
            #expect(
                PhotoExif(dateTimeOriginal: dateTime, offsetTimeOriginal: "+9") == withoutOffset)
            #expect(
                PhotoExif(dateTimeOriginal: dateTime, offsetTimeOriginal: "+09:00:00")
                    == withoutOffset)
        }
    }

    @Suite("撮影時刻が無いとき")
    struct WithoutDateTime {
        @Test("時差があっても、撮影時刻が無いものにすること")
        func isNone() {
            #expect(PhotoExif(dateTimeOriginal: nil, offsetTimeOriginal: "+09:00") == .none)
        }
    }

    @Suite("撮影時刻の形が違うとき")
    struct UnreadableDateTime {
        @Test("撮影時刻が無いものにすること")
        func isNone() {
            // 区切りが違う、時刻が無い、秒が無い、撮った機器が空白で埋めた
            #expect(read("2026-09-24 19:40:12") == .none)
            #expect(read("2026:09:24") == .none)
            #expect(read("2026:09:24 19:40") == .none)
            #expect(read("    :  :     :  :  ") == .none)
        }

        private func read(_ dateTime: String) -> PhotoExif {
            PhotoExif(dateTimeOriginal: dateTime, offsetTimeOriginal: "+09:00")
        }
    }
}

extension PhotoExif {
    /// 読めた時差。撮影時刻が無ければ nil
    fileprivate var utcOffsetSeconds: Int? {
        switch self {
        case .none: nil
        case .takenAt(_, let utcOffsetSeconds): utcOffsetSeconds
        }
    }
}
