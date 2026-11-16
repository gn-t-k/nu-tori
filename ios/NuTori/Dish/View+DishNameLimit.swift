import NuToriCore
import SwiftUI

extension View {
    /// 料理の名前の欄に、上限より先の字を入れない。いったん受けてから戻すと、欄の表示も戻る。
    /// `typed` は打ちかけの文字で、打っていないあいだ（nil）は何もしない
    func dishNameLimit(typed: String?, write: @escaping (String) -> Void) -> some View {
        onChange(of: typed) { _, typed in
            guard let typed else { return }
            let limited = Dish.nameFieldText(typed: typed)
            if limited != typed {
                write(limited)
            }
        }
    }
}
