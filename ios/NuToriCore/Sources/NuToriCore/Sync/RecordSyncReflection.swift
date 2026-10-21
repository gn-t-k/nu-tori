public import Foundation

/// 同期の段取りが、決めたことと読み直したものを反映する先（画面の状態）
public protocol RecordSyncReflection: Sendable {
    func destinationChanged(_ destination: SignInDestination) async

    func writesRejected(_ writes: [RejectedWrite]) async

    /// 記録を直す・消す書き込みを積む前。その記録の受け付けなかった1行を外す
    func recordReplacing(id recordId: UUID) async

    /// 送り待ちから作る見え方（まだ届いていない記録と、まだ送れていない料理）が変わりうるとき
    /// （記録を作った・直した・消した、同期を始めた・終えた）に、読み直して知らせる。送り待ちはキャッシュと別の置き場で、画面からは読めない。
    /// 届いたら（送り待ちから無くなったら）、タイムラインで濃くする
    func pendingAppearanceChanged(_ appearance: PendingAppearance) async

    /// 見守る要求で受け取っている途中の返事が変わったら、送った文章の ID ごとの全部を知らせる
    func replyStreamsChanged(_ streams: [UUID: ReplyStream]) async
}
