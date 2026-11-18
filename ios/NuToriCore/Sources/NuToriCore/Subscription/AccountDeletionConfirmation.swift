/// アカウントを削除する確かめのアラートの文。無料体験中だけ、作り直しても無料体験の残りが戻らないことを足す（#974）
public enum AccountDeletionConfirmation {
    /// `standing` はアカウントを開いたときの状態。まだ届いていなければ nil で、足さない
    public static func message(standing: SubscriptionStanding?) -> String {
        let base = "記録はすぐに消え、元に戻せません。ヘルスケアに書き込んだ体重と栄養は残ります。"
        switch standing {
        case .freeTrial:
            return base + "無料体験の残りは、同じ Apple ID で作り直しても戻りません。"
        case .subscribed, .expired, .testUser, .none:
            return base
        }
    }
}
