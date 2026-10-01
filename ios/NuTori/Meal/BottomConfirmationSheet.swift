import SwiftUI

/// 画面の下から出す確かめ。破壊的な操作と「キャンセル」の2つだけを置く。
/// `confirmationDialog` も `UIAlertController` も、iOS 26 以降の iPhone では下から出ず、吹き出しや中央の窓になる
struct BottomConfirmationSheet: View {
    let message: String
    let destructiveTitle: String
    /// UI テストが探すための名前の前半
    let identifierPrefix: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            VStack(spacing: 8) {
                Button(role: .destructive, action: onConfirm) {
                    Text(destructiveTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("\(identifierPrefix)-confirm")
                Button(role: .cancel, action: onCancel) {
                    Text("キャンセル").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("\(identifierPrefix)-cancel")
            }
            .controlSize(.large)
        }
        .padding([.horizontal, .bottom])
        .padding(.top, 32)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            contentHeight = height
        }
        .presentationDetents([.height(contentHeight)])
    }

    @State private var contentHeight: CGFloat = 0
}
