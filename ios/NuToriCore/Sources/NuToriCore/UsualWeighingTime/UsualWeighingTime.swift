public import Foundation

/// いつもの時刻。サーバーが体重の書き込みごとに学び直して届ける。アカウントに1つ。
/// まだ学んでいなければキャッシュに無い（端末は朝7時を使う）
public struct UsualWeighingTime: Hashable, Sendable {
    /// サーバーが初めて学んだときに振る ID
    public let id: UUID
    /// その日の何分目（0〜1435、5 分単位）。例: 7:15 は 435
    public let minuteOfDay: Int

    public init(id: UUID, minuteOfDay: Int) {
        self.id = id
        self.minuteOfDay = minuteOfDay
    }
}
