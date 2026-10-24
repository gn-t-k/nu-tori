import SwiftUI

private struct GoalSetupDimmedWhileDeciding: ViewModifier {
    let isDeciding: Bool

    func body(content: Content) -> some View {
        content
            // DESIGN.md の押せないボタン（`.disabled` に任せる）に従わず、文と値も薄くする。仕様 #523 の「決める」が、押したら「ほかを薄くして」と決めているため
            .opacity(isDeciding ? 0.4 : 1)
            .disabled(isDeciding)
    }
}

extension View {
    func dimmedWhileDeciding(_ isDeciding: Bool) -> some View {
        modifier(GoalSetupDimmedWhileDeciding(isDeciding: isDeciding))
    }
}
