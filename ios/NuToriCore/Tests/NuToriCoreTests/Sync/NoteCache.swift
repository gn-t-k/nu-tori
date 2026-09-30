/// テストが使う「メモ」の種類のキャッシュ。当てられた変更の数を数える
final class NoteCache: @unchecked Sendable {
    private(set) var appliedChangeCount = 0

    func didApply(_ count: Int) {
        appliedChangeCount += count
    }

    func clear() {
        appliedChangeCount = 0
    }
}
