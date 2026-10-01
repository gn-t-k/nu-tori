/// 送り待ちの箱。受け持つのは、送り待ち、通し番号、読めた種類、全消去。入口は、読むもの（`pendingEntries`、`syncState`）、当てるもの（`apply`）、消すもの（`eraseAll`）と、登録簿の種類（`recordKinds`）。
/// 保存の約束
/// - 送り待ちに足すものは先に保存し、キャッシュをそのあとに保存する（ADR-0022）
/// - 通し番号は、保存した変更を追い越さない。100 件ずつ分けて保存してよい
/// - 全消去は、1つの保存で送り待ちを全部消す
public protocol SyncBox: Sendable {
    /// 送り待ちを読む。古い順
    func pendingEntries() async throws -> [PendingEntry]

    /// 同期の状態（通し番号、初回の取得の印、読めた種類、使い始めた日）。まだ無ければ nil
    func syncState() async throws -> SyncState?

    /// 結果を当てる。push の結果も、pull の頁も、ローカルでの記録の変更も、この1つで当てる
    func apply(_ result: SyncBoxResult) async throws

    /// キャッシュの記録、アカウントの設定、送り待ち、同期の状態（通し番号、初回の取得の印、使い始めた日）、ヘルスケアの同期の進み具合を空にする。送り待ちは1つの保存で消す。片方だけ残ると、別のアカウントのものが混ざる
    func eraseAll() async throws

    /// 登録簿の種類。送り待ちと取りに行った変更は、この種類が受け持つ
    var recordKinds: [any SyncedRecordKind] { get }
}
