public import Foundation

/// サーバーが受け付けなかった書き込みを、タイムラインに一時的に出す1行の並び。体重と食事を1本で持つ
public struct RejectedLines: Sendable, Equatable {
    public private(set) var lines: [RejectedLine] = []

    public init() {}

    /// 受け付けなかった書き込みの1行を足す。同じ記録の古い1行は消してから足す
    public mutating func add(_ writes: [RejectedWrite]) {
        for write in writes {
            let line = RejectedLine(write.record)
            remove(recordId: line.recordId)
            lines.append(line)
        }
    }

    /// その記録の1行を消す。直す前に、前に受け付けなかった1行を消すため
    public mutating func remove(recordId: UUID) {
        lines.removeAll { $0.recordId == recordId }
    }

    /// 全部捨てる。前のアカウントの記録の1行を、次にサインインしたアカウントに出さないため
    public mutating func removeAll() {
        lines.removeAll()
    }
}
