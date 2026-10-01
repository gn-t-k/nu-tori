import Foundation
import NuToriCore
import Testing

@Suite("サーバーが受け付けなかった食事の1行")
struct RejectedMealLineTests {
    @Suite("ロサンゼルスで 12:10 に撮った食事のとき")
    struct EatenInLosAngeles {
        let line: RejectedMealLine

        init() throws {
            line = RejectedMealLine(
                meal: try .fixture(
                    eatenAt: "2026-09-24T19:10:00Z", utcOffsetSeconds: -7 * 3600,
                    sentAt: "2026-09-24T19:11:00Z", in: "America/Los_Angeles"))
        }

        @Test("撮った時刻を食事の時差の時計で出すこと")
        func showsEatenClockTime() {
            #expect(line.text == "12:10 の食事は、記録できませんでした。")
        }
    }
}
