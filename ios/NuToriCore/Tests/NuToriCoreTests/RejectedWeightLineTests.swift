import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("サーバーが受け付けなかった体重の1行")
struct RejectedWeightLineTests {
    @Suite("新しく作った記録を受け付けなかったとき")
    struct CreatedRecord {
        let line: RejectedWeightLine

        init() throws {
            let record = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 1)
            line = RejectedWeightLine(
                RejectedWrite(writeId: UUID(), record: record, reason: .outOfRange))
        }

        @Test("行を消した位置に、時刻と値の文を出すこと")
        func replacesTheRow() {
            #expect(line.placement == .insteadOfRecord)
            #expect(line.text == "7:12 の体重 72.4 kg は、記録できませんでした。")
        }
    }

    @Suite("直した値を受け付けなかったとき")
    struct CorrectedRecord {
        let line: RejectedWeightLine

        init() throws {
            let record = try WeightRecord.manual(
                71.9, at: "2026-09-24T08:00:00+09:00", in: "Asia/Tokyo", version: 2)
            line = RejectedWeightLine(
                RejectedWrite(writeId: UUID(), record: record, reason: .versionTooLow))
        }

        @Test("元の行のすぐ下に、直せなかった値の文を出すこと")
        func placesBelowTheRestoredRow() {
            #expect(line.placement == .belowRecord)
            #expect(line.text == "71.9 kg に直せませんでした。")
        }
    }
}
