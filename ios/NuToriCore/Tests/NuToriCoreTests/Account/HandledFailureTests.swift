import Foundation
import NuToriCore
import Testing

@Suite("対処した失敗を送るか")
struct HandledFailureTests {
    struct SampleError: Error {}

    @Suite("電波が無いとき")
    struct Unreachable {
        let error: URLError

        init() {
            error = URLError(.notConnectedToInternet)
        }

        @Test("送らないこと")
        func skips() {
            #expect(HandledFailure.reported(error, as: .sync) == nil)
        }
    }

    @Suite("時間切れのとき")
    struct TimedOut {
        let error: URLError

        init() {
            error = URLError(.timedOut)
        }

        @Test("送らないこと")
        func skips() {
            #expect(HandledFailure.reported(error, as: .healthRead) == nil)
        }
    }

    @Suite("接続が切れたとき")
    struct ConnectionLost {
        let error: URLError

        init() {
            error = URLError(.networkConnectionLost)
        }

        @Test("送らないこと")
        func skips() {
            #expect(HandledFailure.reported(error, as: .healthWrite) == nil)
        }
    }

    @Suite("キャンセルされたとき")
    struct Cancelled {
        let error: CancellationError

        init() {
            error = CancellationError()
        }

        @Test("送らないこと")
        func skips() {
            #expect(HandledFailure.reported(error, as: .cacheSave) == nil)
        }
    }

    @Suite("端末のロック中でヘルスケアのデータを読み書きできないとき")
    struct HealthDataLocked {
        let error: NSError

        init() {
            error = NSError(domain: "com.apple.healthkit", code: 6)
        }

        @Test("送らないこと")
        func skips() {
            #expect(HandledFailure.reported(error, as: .healthRead) == nil)
        }
    }

    @Suite("それ以外の失敗のとき")
    struct OtherFailure {
        let error: SampleError

        init() {
            error = SampleError()
        }

        @Test("同期の場所だけを送ること")
        func reportsSync() {
            #expect(HandledFailure.reported(error, as: .sync) == .sync)
        }

        @Test("キャッシュの保存の場所だけを送ること")
        func reportsCacheSave() {
            #expect(HandledFailure.reported(error, as: .cacheSave) == .cacheSave)
        }
    }
}
