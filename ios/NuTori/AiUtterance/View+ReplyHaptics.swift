import NuToriCore
import SwiftUI

extension View {
    /// 待っていた返事の結果が出た瞬間に、結果ごとの触覚を鳴らす。送り直した返事も同じ
    func replyHaptics(for items: [Timeline.Item]) -> some View {
        let progress = ReplyProgress(items: items)
        return
            haptic(.replyArrived, trigger: progress) { old, new in
                new.hasReplied(since: old)
            }
            .haptic(.replyFailed, trigger: progress) { old, new in
                new.hasFailed(since: old)
            }
    }
}
