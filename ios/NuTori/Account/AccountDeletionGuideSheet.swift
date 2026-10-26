import NuToriCore
import StoreKit
import SwiftUI

/// 退会の案内。アカウントを削除しても Apple の請求が続くことを知らせ、1. 解約、2. 削除の順に道を示す。解約しなくても削除できる
struct AccountDeletionGuideSheet: View {
    let actions: Actions

    var body: some View {
        NavigationStack {
            List {
                Section {
                    switch guide.renewal {
                    case .autoRenewing:
                        LabeledContent("サブスクリプション", value: guide.subscriptionText)
                        LabeledContent("次の請求", value: guide.nextBillingText)
                    case .cancelled:
                        LabeledContent("サブスクリプション", value: "解約しました")
                        LabeledContent("使える日", value: guide.usableThroughText)
                    }
                } footer: {
                    switch guide.renewal {
                    case .autoRenewing: Text("アカウントを削除しても、Apple の請求は続きます。")
                    case .cancelled: EmptyView()
                    }
                }
                Section {
                    switch guide.renewal {
                    case .autoRenewing:
                        VStack(alignment: .leading) {
                            step(guide.cancellationStepText, systemImage: "1.circle")
                            Button("サブスクリプションを解約") {
                                showsManageSubscriptions = true
                                Task { await actions.openedManageSubscriptions() }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("manage-subscriptions")
                        }
                    case .cancelled:
                        step("サブスクリプションを解約しました。", systemImage: "checkmark.circle.fill")
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        step("アカウントを削除する。記録はすぐに消え、元に戻せません。", systemImage: "2.circle")
                        Button("アカウントを削除", role: .destructive, action: actions.proceedToDeletion)
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("account-deletion-guide-delete")
                    }
                }
            }
            .navigationTitle("アカウントの削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: actions.cancel)
                }
            }
            // 仕様の showManageSubscriptions を、SwiftUI の同じ画面を出す修飾子で開く。閉じたことを isPresented で受け取れるため
            .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
            .onChange(of: showsManageSubscriptions) { _, shows in
                guard !shows else { return }
                Task { guide = await actions.reread(guide) }
            }
        }
    }

    /// guide は開いたときの案内。解約の画面から戻ると、シートの中で読み直す
    init(guide: AccountDeletionGuide, actions: Actions) {
        self.actions = actions
        _guide = State(initialValue: guide)
    }

    struct Actions {
        let reread: (AccountDeletionGuide) async -> AccountDeletionGuide
        let openedManageSubscriptions: () async -> Void
        /// 「アカウントを削除」。シートを閉じて、今の確かめのダイアログへ進む
        let proceedToDeletion: () -> Void
        let cancel: () -> Void
    }

    @State private var guide: AccountDeletionGuide
    @State private var showsManageSubscriptions = false

    private func step(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }
}
