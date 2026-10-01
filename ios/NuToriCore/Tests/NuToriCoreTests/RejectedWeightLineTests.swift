import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("サーバーが受け付けなかった体重の1行")
struct RejectedWeightLineTests {
    @Suite("サーバーに記録が無いとき")
    struct NoValueOnServer {
        let line: RejectedWeightLine

        init() throws {
            let record = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 1)
            line = RejectedWeightLine(record: record, serverHasValue: false)
        }

        @Test("記録の時刻の位置に、時刻と値の文を出すこと")
        func replacesTheRow() {
            #expect(line.placement == .insteadOfRecord)
            #expect(line.text == "7:12 の体重 72.4 kg は、記録できませんでした。")
        }
    }

    @Suite("サーバーに記録の値があるとき")
    struct ValueOnServer {
        let line: RejectedWeightLine

        init() throws {
            let record = try WeightRecord.manual(
                71.9, at: "2026-09-24T08:00:00+09:00", in: "Asia/Tokyo", version: 2)
            line = RejectedWeightLine(record: record, serverHasValue: true)
        }

        @Test("その値の記録のすぐ下に、直せなかった値の文を出すこと")
        func placesBelowTheRestoredRow() {
            #expect(line.placement == .belowRecord)
            #expect(line.text == "71.9 kg に直せませんでした。")
        }
    }
}
