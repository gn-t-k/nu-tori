/// 締め出されたことを、そのときのビルド番号と一緒に覚える置き場。電波が無くても、開いたときにすぐ読めるよう、端末に置く
public protocol AppLockoutStore: Sendable {
    /// 締め出されたときのビルド番号。覚えていなければ nil
    func lockedOutBuild() -> Int?
    func remember(lockedOutBuild build: Int)
    func forget()
}
