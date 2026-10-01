import NuToriCore
import SwiftUI

/// 栄養の出典。食事の画面の「栄養の出典 ›」から潜る。成分表を使った材料がある食事だけに行を置く
struct NutrientCitationScreen: View {
    let capture: (ClientUsageEvent) async -> Void

    var body: some View {
        List {
            Section {
                Text("日本食品標準成分表（八訂）増補2023年から引用しています。材料への当てはめと、量からの計算は nu-tori が行っています。")
            }
        }
        .navigationTitle("栄養の出典")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await capture(.screen(.nutrientCitation)) }
        }
    }
}
