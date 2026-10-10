import SwiftUI

/// DESIGN.md の「待っている表示」の、まだ届いていない記録（`UndeliveredRecords`）。記録の全体を薄く描き、届いたら濃くする。
/// インターネットにつながるかは iPhone の状態表示で分かるので、画面の文では書かない。
/// 押したときはふつうの記録と同じに潜れるよう、押せるかは変えない
private struct UndeliveredRecordStyle: ViewModifier {
    let undelivered: Bool

    func body(content: Content) -> some View {
        content
            // 不透明度だけを動かす（同じときに変わった値まで動かさない）。
            // 位置が動かないので、「視差効果を減らす」がオンでも同じに動かす。動きはあとで #325 で見直す
            .animation(.easeInOut(duration: 0.25)) {
                $0.opacity(undelivered ? 0.55 : 1)
            }
            // 見えなくても届いていないと分かるよう、読み上げの最後に添える
            .accessibilityLabel { label in
                label
                if undelivered {
                    Text("送信待ち")
                }
            }
    }
}

extension View {
    /// 体重の行、食事のカード、送った文章の吹き出しに付ける
    func undeliveredRecord(_ undelivered: Bool) -> some View {
        modifier(UndeliveredRecordStyle(undelivered: undelivered))
    }
}
