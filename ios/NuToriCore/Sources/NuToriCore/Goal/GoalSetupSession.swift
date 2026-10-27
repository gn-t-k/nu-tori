import Foundation
public import Observation

/// 目標を立てる知らせのカードが広げる、目標の設定の流れを持つ。閉じても流れを残し、開き直すと同じページから続ける。
/// 流れは初めて開くときに、そのときの状況（初めてか立て直しか）で作る。サインアウトで捨てる
@MainActor
@Observable
public final class GoalSetupSession {
    /// - Parameters:
    ///   - start: その人の状況をキャッシュから決める（`RecordSync.goalSetupStart(today:)`）
    ///   - makeFlow: 状況から流れを作る。要求のクライアントと同期の段取り、ヘルスケアの口は作る側が渡す
    public init(
        today: @escaping () -> CalendarDay,
        start: @escaping (CalendarDay) async throws -> GoalSetupStart,
        makeFlow: @escaping (GoalSetupStart) -> GoalSetupFlow
    ) {
        self.today = today
        self.start = start
        self.makeFlow = makeFlow
    }

    /// 開いたことのある流れ。まだ開いていなければ nil。広げているか、「続ける」にするかは流れが持つ
    public private(set) var flow: GoalSetupFlow?
    /// 流れを最後に開いた場所。広げたカードは、この場所にだけ描く
    public private(set) var place: Place = .timeline

    /// カードを広げる。途中まで進めていれば同じページから。決めたあとに開くときは、新しく始める。
    /// 広げたまま別の場所から開いたときは、描く場所だけを移す
    public func open(from entry: GoalSetupObservation.Entry, on place: Place) async {
        guard !isOpening else { return }
        self.place = place
        guard flow?.isOpen != true else { return }
        if flow == nil || flow?.decision == .decided {
            isOpening = true
            defer { isOpening = false }
            // キャッシュを読めなければ開かない（読み出しの失敗は置き場が報告する）
            guard let start = try? await start(today()) else { return }
            flow = makeFlow(start)
        }
        flow?.open(from: entry)
    }

    /// サインアウトとアカウントの削除。前のアカウントの答え（身体データを含む）を次のアカウントに持ち越さない
    public func discard() {
        flow = nil
    }

    /// 流れを開いた場所
    public enum Place: Sendable {
        /// タイムライン（知らせのカードと、目標があるあいだは一番下のカード）。日のまとめと体重の画面から開いたときもここに戻って描く
        case timeline
        /// 目標の画面の、今の目標のカードの場所
        case goalScreen
    }

    private let today: () -> CalendarDay
    private let start: (CalendarDay) async throws -> GoalSetupStart
    private let makeFlow: (GoalSetupStart) -> GoalSetupFlow
    /// 状況を読んでいるあいだに2回押されても、流れを2つ作らない
    private var isOpening = false
}
