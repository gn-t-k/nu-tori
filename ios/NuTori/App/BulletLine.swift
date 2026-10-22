import SwiftUI

/// 箇条書きの1行。折り返した行を「・」の右にそろえる。文の中の改行と「・」だけでは、2行目が「・」の下から始まる。
/// 文字の大きさと色は、置く側の `.font`・`.foregroundStyle` に従う
struct BulletLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("・")
            Text(text)
                // 高さを詰めて並べる欄でも、大きな文字で「…」で切らずに折り返す
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
