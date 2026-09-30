import NuToriCore
import Testing

@Suite("送り待ちの列を送り切る")
struct CancellableFlushTests {
    @Test("キャンセルされたら、送り切りを待たずに戻ること")
    func returnsWhenCancelled() async {
        let started = ContinuousClock.now
        let task = Task {
            await CancellableFlush.run {
                try? await Task.sleep(for: .seconds(30))
            }
        }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        #expect(ContinuousClock.now - started < .seconds(2))
    }
}
