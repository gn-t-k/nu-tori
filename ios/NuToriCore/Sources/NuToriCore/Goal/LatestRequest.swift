/// 最後に始めた要求の答えだけを使うための、世代の番号と、その要求の Task。
/// 前の要求は取り消さずに走らせ、答えを当てる前に `isLatest` で自分が最後かを確かめさせる
@MainActor
struct LatestRequest {
    /// 最後に始めた要求。終われば `finish` で外す
    private(set) var task: Task<Void, Never>?

    /// 走っている要求の答えを、どれも使わないようにする
    mutating func invalidate() {
        generation += 1
    }

    /// 新しい要求を始める。`operation` は自分の世代を受け取る
    mutating func start(_ operation: @escaping @MainActor (_ generation: Int) async -> Void)
        -> Task<Void, Never>
    {
        generation += 1
        let generation = generation
        let task = Task { await operation(generation) }
        self.task = task
        return task
    }

    func isLatest(_ generation: Int) -> Bool {
        generation == self.generation
    }

    /// 終わった要求が最後に始めたものなら外す
    mutating func finish(_ task: Task<Void, Never>) {
        if self.task == task {
            self.task = nil
        }
    }

    private var generation = 0
}
