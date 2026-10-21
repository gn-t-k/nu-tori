import Foundation
import NuToriCore
import SwiftUI
import UIKit

struct AccountScreen: View {
    /// 一番上の「サブスクリプション」の行。サブスクリプションの状態がまだ届いていなければ nil で、行を出さない
    let subscription: AccountSubscriptionRow?
    let openPaywall: () -> Void
    /// 保存してある「利用状況を送る」
    let sendsUsageData: Bool
    let cameraAccess: CameraAccess
    /// 読み終えるまでは nil で、値を出さない
    let notificationPermission: NotificationPermission?
    // 版とビルド番号は、問い合わせのときに見てもらう
    let appVersion: String
    let appBuild: Int
    let actions: AccountActions
    let onClose: () -> Void

    var body: some View {
        List {
            if let subscription {
                subscriptionSection(subscription)
            }
            Section {
                NavigationLink {
                    HealthAccessScreen()
                } label: {
                    LabeledContent("ヘルスケア", value: "読む・書く")
                }
            }
            Section("通知") {
                LabeledContent("記録忘れ（体重）", value: notificationPermission?.label ?? "")
                    .accessibilityIdentifier("notification-permission")
                Button {
                    openURL(Self.notificationSettingsURL)
                    Task { await actions.openedNotificationSettings() }
                } label: {
                    externalLinkLabel("iPhone の設定を開く")
                }
            }
            Section("カメラ") {
                LabeledContent("食事を撮る", value: cameraAccess.label)
                    .accessibilityIdentifier("camera-access")
                externalLink("iPhone の設定を開く", url: Self.appSettingsURL)
            }
            Section {
                Toggle("利用状況を送る", isOn: shownSendsUsageData)
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
                Button(role: .destructive) {
                    Task { await requestDeletion() }
                } label: {
                    HStack {
                        Text("アカウントを削除")
                        if isDeleting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeleting)
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
            Section {
            } footer: {
                Text("\(appVersion) (\(appBuild))")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("app-version")
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了", action: onClose)
                    .disabled(isDeleting)
            }
        }
        // 消している途中で閉じると、消せなかったときの1行を出す先が無くなる
        .interactiveDismissDisabled(isDeleting)
        .sheet(
            item: $presentedDeletionGuide,
            onDismiss: {
                // シートを閉じ終えてから出さないと、確かめのダイアログが出ない
                if proceedsAfterDeletionGuide {
                    proceedsAfterDeletionGuide = false
                    confirmingDeletion = true
                }
            }
        ) { presented in
            AccountDeletionGuideSheet(
                guide: presented.guide,
                actions: AccountDeletionGuideSheet.Actions(
                    reread: actions.rereadAccountDeletionGuide,
                    openedManageSubscriptions: actions.openedManageSubscriptions,
                    proceedToDeletion: {
                        proceedsAfterDeletionGuide = true
                        presentedDeletionGuide = nil
                    },
                    cancel: { presentedDeletionGuide = nil }
                )
            )
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

    /// deletion は開いたときの状態。削除は画面の中で進むので、あとから渡し直しても変わらない
    init(
        subscription: AccountSubscriptionRow?,
        openPaywall: @escaping () -> Void,
        sendsUsageData: Bool,
        cameraAccess: CameraAccess,
        notificationPermission: NotificationPermission?,
        deletion: Deletion,
        appVersion: String,
        appBuild: Int,
        actions: AccountActions,
        onClose: @escaping () -> Void
    ) {
        self.subscription = subscription
        self.openPaywall = openPaywall
        self.sendsUsageData = sendsUsageData
        self.cameraAccess = cameraAccess
        self.notificationPermission = notificationPermission
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.actions = actions
        self.onClose = onClose
        _deletion = State(initialValue: deletion)
    }

    enum Deletion {
        case idle
        case deleting
        case failed(AccountDeletionFailure)
    }

    /// シートの `item` に渡すため。開くたびに別のシートとして出す
    private struct PresentedDeletionGuide: Identifiable {
        let id = UUID()
        let guide: AccountDeletionGuide
    }

    @Environment(\.openURL) private var openURL
    /// 切り替えてから保存し終えるまで、スイッチを押した側に置いておく
    @State private var requestedSendsUsageData: Bool?
    @State private var accountId: String?
    @State private var deletion: Deletion
    @State private var confirmingDeletion = false
    @State private var presentedDeletionGuide: PresentedDeletionGuide?
    /// 退会の案内の「アカウントを削除」で閉じた。閉じ終えたら確かめのダイアログを出す
    @State private var proceedsAfterDeletionGuide = false

    private static let privacyPolicyURL = URL(string: "https://nu-tori.app/privacy")!
    /// このアプリの iPhone の設定
    private static let appSettingsURL = URL(string: UIApplication.openSettingsURLString)!
    /// iPhone の設定の、このアプリの通知の設定
    private static let notificationSettingsURL = URL(
        string: UIApplication.openNotificationSettingsURLString)!

    private var isDeleting: Bool {
        switch deletion {
        case .deleting: true
        case .idle, .failed: false
        }
    }

    private var deletionFailure: AccountDeletionFailure? {
        switch deletion {
        case .idle, .deleting: nil
        case .failed(let failure): failure
        }
    }

    private var shownSendsUsageData: Binding<Bool> {
        Binding(
            get: { requestedSendsUsageData ?? sendsUsageData },
            set: { requested in
                requestedSendsUsageData = requested
                Task {
                    if requested {
                        await actions.turnOnUsageData()
                    } else {
                        await actions.turnOffUsageData()
                    }
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

    private func subscriptionSection(_ row: AccountSubscriptionRow) -> some View {
        Section {
            if row.opensPaywall {
                Button(action: openPaywall) {
                    HStack {
                        // ボタンに付けた .primary が値にも及ぶので、ほかの行の値と同じ secondary に戻す
                        LabeledContent("サブスクリプション") {
                            Text(row.value)
                                .foregroundStyle(.secondary)
                        }
                        // 大きな文字では見出しと値を縦に積んで幅が縮むので、印をほかの行と同じ右端に寄せる
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("subscription-row")
            } else {
                LabeledContent("サブスクリプション", value: row.value)
                    .accessibilityIdentifier("subscription-row")
            }
        } footer: {
            if let note = row.note {
                Text(note)
            }
        }
    }

    private func externalLink(_ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            externalLinkLabel(title)
        }
    }

    private func externalLinkLabel(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// サブスクリプション中で自動更新がオンなら、確かめの前に退会の案内を出す
    private func requestDeletion() async {
        guard let guide = await actions.accountDeletionGuide() else {
            confirmingDeletion = true
            return
        }
        presentedDeletionGuide = PresentedDeletionGuide(guide: guide)
        await actions.openedAccountDeletionGuide()
    }

    private func deleteAccount() async {
        if isDeleting { return }
        deletion = .deleting
        if let failure = await actions.deleteAccount() {
            deletion = .failed(failure)
        } else {
            deletion = .idle
        }
    }
}

extension NotificationPermission {
    fileprivate var label: String {
        switch self {
        case .permitted: "許可している"
        case .notPermitted: "許可していない"
        case .notYetRequested: "まだ求めていない"
        }
    }
}
