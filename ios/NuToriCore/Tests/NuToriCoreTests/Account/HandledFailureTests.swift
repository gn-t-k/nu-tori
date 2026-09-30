import Foundation
import NuToriCore
import Testing

@Suite("対処した失敗を送るか")
struct HandledFailureTests {
    struct SampleError: Error {}

    @Test("電波が無い失敗と時間切れは送らないこと")
    func skipsUnreachableAndTimeout() {
        #expect(HandledFailure.reported(URLError(.notConnectedToInternet), as: .sync) == nil)
        #expect(HandledFailure.reported(URLError(.timedOut), as: .healthRead) == nil)
        #expect(HandledFailure.reported(URLError(.networkConnectionLost), as: .healthWrite) == nil)
        #expect(HandledFailure.reported(CancellationError(), as: .cacheSave) == nil)
    }

    @Test("それ以外の失敗は、起きた場所だけを送ること")
    func reportsTheArea() {
        #expect(HandledFailure.reported(SampleError(), as: .sync) == .sync)
        #expect(HandledFailure.reported(SampleError(), as: .cacheSave) == .cacheSave)
    }
}
