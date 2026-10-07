import SwiftUI

/// 締め出しの画面。すべての画面に替えて全面に出し、説明と更新のボタンだけを載せる
struct AppLockoutScreen: View {
    /// isOpening は画面を出したときの状態。更新する場所を開くのは画面の中で進むので、あとから渡し直しても変わらない
    init(isOpening: Bool, openUpdate: @escaping () async -> Void) {
        _isOpening = State(initialValue: isOpening)
        self.openUpdate = openUpdate
    }

    /// 更新する場所を開く。どこから入れた版かを見分け終えるまで待つことがある
    let openUpdate: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 文字を大きくして入りきらないときは、更新のボタンをいつも画面の下に見せるため、説明だけを送る
            ViewThatFits(in: .vertical) {
                message
                    .frame(maxHeight: .infinity)
                ScrollView {
                    message
                }
            }
            Button {
                // 開くのを待つあいだに続けて押されても、二重に開かない
                guard !isOpening else { return }
                isOpening = true
                Task {
                    await openUpdate()
                    isOpening = false
                }
            } label: {
                HStack {
                    Text("更新する")
                    if isOpening {
                        ProgressView()
                            // 既定の色は塗りと同じ Primary で見えないので、文字と同じ on-primary にする
                            .tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding([.horizontal, .bottom])
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app-lockout")
    }

    /// 押してから、更新する場所を開くまでのあいだ
    @State private var isOpening: Bool

    private var message: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.circle")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("アップデートしてください")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("このバージョンの nu-tori は使えなくなりました。最新のバージョンに更新すると、続けて使えます。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
