import NuToriCore
import SwiftData
import SwiftUI

struct AccountScreen: View {
    let actions: AccountActions
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                NavigationLink {
                    HealthAccessScreen()
                } label: {
                    LabeledContent("ヘルスケア", value: "読む・書く")
                }
            }
            Section {
                Toggle("利用状況を送る", isOn: sendsUsageData)
                    // 続けて押すと、先に押した分の保存があとから届き、最後に押した値を上書きしうる
                    .disabled(requestedSendsUsageData != nil)
            } footer: {
                Text("オフにすると、これから先は送りません。送った分は1年で消えます。")
            }
            Section {
                externalLink("プライバシーポリシー", url: Self.privacyPolicyURL)
                externalLink("問い合わせ", url: inquiryURL)
            }
            Section {
                Button("アカウントを削除", role: .destructive) {
                    confirmingDeletion = true
                }
            } header: {
                if let deletionFailure {
                    Text(deletionFailure.message)
                        .font(.footnote)
                        .foregroundStyle(Color(.label))
                        .textCase(nil)
                        .accessibilityIdentifier("account-deletion-failure")
                }
            } footer: {
                Text(
                    "食事、体重、目標、会話の記録はすぐに消え、元に戻せません。エラーの報告と利用状況のデータは、最長 90 日で消えます。"
                )
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了", action: onClose)
            }
        }
        .alert("アカウントを削除しますか？", isPresented: $confirmingDeletion) {
            Button("アカウントを削除", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("記録はすぐに消え、元に戻せません。ヘルスケアに書き込んだ体重と栄養は残ります。")
        }
        .task {
            accountId = await actions.signedInAccountId()
        }
    }

    @Environment(\.openURL) private var openURL
    @Query private var cachedSettings: [CachedAccountSettings]
    /// 切り替えてから保存し終えるまで、スイッチを押した側に置いておく
    @State private var requestedSendsUsageData: Bool?
    @State private var accountId: String?
    @State private var deletion = Deletion.idle
    @State private var confirmingDeletion = false

    private enum Deletion {
        case idle
        case deleting
        case failed(AccountDeletionFailure)
    }

    private static let privacyPolicyURL = URL(string: "https://nu-tori.app/privacy")!

    private var deletionFailure: AccountDeletionFailure? {
        switch deletion {
        case .idle, .deleting: nil
        case .failed(let failure): failure
        }
    }

    private var sendsUsageData: Binding<Bool> {
        Binding(
            get: {
                requestedSendsUsageData
                    ?? UsageDataSetting.sendsUsageData(
                        cachedSettings.first?.accountSettings())
            },
            set: { sendsUsageData in
                requestedSendsUsageData = sendsUsageData
                Task {
                    await actions.setSendsUsageData(sendsUsageData)
                    requestedSendsUsageData = nil
                }
            }
        )
    }

    /// アカウント ID を読み終えるまでは、事前入力の無いフォームを開く
    private var inquiryURL: URL {
        var components = URLComponents(
            string:
                "https://docs.google.com/forms/d/e/1FAIpQLSdHsd92hXKR20it2cOAj70P3OQXpHfe3p6BRDmBBZVxILxjSg/viewform"
        )!
        components.queryItems = [URLQueryItem(name: "usp", value: "pp_url")]
        if let accountId {
            components.queryItems?.append(URLQueryItem(name: "entry.2004378953", value: accountId))
        }
        return components.url!
    }

    private func externalLink(_ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deleteAccount() async {
        if case .deleting = deletion { return }
        deletion = .deleting
        if let failure = await actions.deleteAccount() {
            deletion = .failed(failure)
        } else {
            deletion = .idle
        }
    }
}
