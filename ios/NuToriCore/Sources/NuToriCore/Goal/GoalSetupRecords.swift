public import Foundation
public import NuToriAPI

/// 目標の設定の流れが、同期の段取り（`RecordSync`）に頼むこと
public protocol GoalSetupRecords: Sendable {
    /// その人の状況。キャッシュの目標・体重記録と、使い始めた日から決める
    func goalSetupStart(today: CalendarDay) async throws -> GoalSetupStart

    /// 初めての目標の下見の前に、ヘルスケアの体重を取り込み、送り待ちの体重記録を同期で送り切る。
    /// 送り切ったら true。電波が無い、同期が止まった、送り待ちに体重記録が残ったら false
    func sendWeightRecordsForGoalSetup() async -> Bool

    /// 足りない値で入れた今の体重を、今日の体重記録として送り待ちに入れる
    func recordWeight(kilograms: Double, at instant: Date, in timeZone: TimeZone) async throws

    /// 目標を決める要求の応答の記録を、取りに行った変更と同じ道でキャッシュに当てる
    func applyGoalDecision(_ changes: [SyncChange]) async throws

    /// 目標が決まったときに、目標を立てる知らせに答える
    func respondToGoalSetupNotice() async
}
