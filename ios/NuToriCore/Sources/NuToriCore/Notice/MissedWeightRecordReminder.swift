public import Foundation

/// 予約する記録忘れの通知の1つ。通知の層（`UNUserNotificationCenter`）は、これを今の土地の時計の時刻で予約する。
/// どの日のどの時刻に予約するかは、記録忘れの計画（`MissedWeightRecordPlan`）が決める
public struct MissedWeightRecordReminder: Hashable, Sendable {
    /// 予約の ID。その日の体重の知らせの ID と同じ値にし、押したときにどの日の分かを分かるようにする
    public let id: UUID
    public let day: CalendarDay
    /// 今のタイムゾーンでの時計の時刻
    public let clockTime: ClockTime
    public let fireDate: Date
}
