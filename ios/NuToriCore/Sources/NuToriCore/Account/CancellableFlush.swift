public enum CancellableFlush {
    public static func run(_ work: @escaping @Sendable () async -> Void) async {
        if Task.isCancelled { return }
        let finished = FinishFlag()
        Task {
            await work()
            await finished.markFinished()
        }
        while await finished.isFinished() == false {
            if Task.isCancelled { return }
            do {
                try await Task.sleep(for: .milliseconds(20))
            } catch {
                return
            }
        }
    }
}

private actor FinishFlag {
    func markFinished() {
        finished = true
    }

    func isFinished() -> Bool {
        finished
    }

    private var finished = false
}
