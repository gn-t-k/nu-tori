public import Foundation

/// いつもの時刻。サーバーだけが書く。アカウントに1つで、ID はサーバーが初めて学んだときに振る。
/// 学ぶまでは届かず、一度届いたら消えない
public struct SyncedUsualWeighingTime: Sendable, Equatable {
    public let id: UUID
    /// その日の何分目（0〜1435、5 分単位）。例: 7:15 は 435
    public let minuteOfDay: Int

    public init(id: UUID, minuteOfDay: Int) {
        self.id = id
        self.minuteOfDay = minuteOfDay
    }
}
