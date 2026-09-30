import NuToriCore
import SwiftUI

struct AccountScreen: View {
    let session: AccountSession
    let onClose: () -> Void
    let onLeftTimeline: (SignInDestination) -> Void

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
                Toggle("利用状況を送る", isOn: usageBinding)
            } footer: {
                Text("オフにすると、これから先は送りません。送った分は1年で消えます。")
            }
            Section {
                externalLink("プライバシーポリシー", url: privacyURL)
                if let inquiryURL {
                    externalLink("問い合わせ", url: inquiryURL)
                }
            }
            Section {
                Button("アカウントを削除", role: .destructive) {
                    confirmingDelete = true
                }
            } header: {
                if let deleteFailure {
                    Text(deleteFailure.message)
                        .font(.footnote)
                        .foregroundStyle(Color(.label))
                        .textCase(nil)
                        .accessibilityIdentifier("accountDeleteFailure")
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
        .alert("アカウントを削除しますか？", isPresented: $confirmingDelete) {
            Button("アカウントを削除", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("記録はすぐに消え、元に戻せません。ヘルスケアに書き込んだ体重と栄養は残ります。")
        }
        .task { await load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("account")
    }

    @Environment(\.openURL) private var openURL
    @State private var sendsUsageData = true
    @State private var accountId = ""
    @State private var deleteFailure: AccountDeleteFailure?
    @State private var confirmingDelete = false
    @State private var isDeleting = false

    private var privacyURL: URL {
        URL(string: "https://nu-tori.app/privacy")!
    }

    private var inquiryURL: URL? {
        guard !accountId.isEmpty else { return nil }
        let formID = "1FAIpQLSdHsd92hXKR20it2cOAj70P3OQXpHfe3p6BRDmBBZVxILxjSg"
        var components = URLComponents(
            string: "https://docs.google.com/forms/d/e/\(formID)/viewform")
        components?.queryItems = [
            URLQueryItem(name: "usp", value: "pp_url"),
            URLQueryItem(name: "entry.2004378953", value: accountId),
        ]
        return components?.url
    }

    private var usageBinding: Binding<Bool> {
        Binding(
            get: { sendsUsageData },
            set: { newValue in
                let previous = sendsUsageData
                sendsUsageData = newValue
                Task { await changeUsage(to: newValue, revertingTo: previous) }
            }
        )
    }

    private func externalLink(_ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func load() async {
        async let usage = session.sendsUsageData()
        async let id = session.currentAccountId()
        sendsUsageData = await usage
        accountId = await id ?? ""
    }

    private func changeUsage(to newValue: Bool, revertingTo previous: Bool) async {
        do {
            try await session.changeSendsUsageData(to: newValue)
        } catch is CancellationError {
            return
        } catch {
            sendsUsageData = previous
        }
    }

    private func deleteAccount() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            switch try await session.deleteAccount() {
            case .deleted:
                onLeftTimeline(.signIn(.introduction))
            case .unreachable:
                deleteFailure = .unreachable
            case .retryLater:
                deleteFailure = .retryLater
            case .signInRequired(let destination):
                onLeftTimeline(destination)
            }
        } catch is CancellationError {
            return
        } catch {
            deleteFailure = .retryLater
        }
    }
}

private enum AccountDeleteFailure: Equatable {
    case unreachable
    case retryLater

    var message: String {
        switch self {
        case .unreachable:
            "インターネットにつながらないため、削除できませんでした。つながるところで、もう一度押してください。"
        case .retryLater:
            "削除できませんでした。しばらくしてから、もう一度押してください。"
        }
    }
}
