import Foundation

/// 記録忘れの通知を押して開いたときの着き先。ヘルスケアを読み、知らせを出すかを決めてから決める
enum ReminderLanding: Equatable {
    /// その日の体重の知らせ（答えていても）の位置
    case notice(id: UUID)
    /// 知らせが無いので、ふだん開いたときと同じ、今日のいちばん下
    case timelineEnd
}
