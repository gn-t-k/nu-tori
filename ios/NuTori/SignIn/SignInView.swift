import NuToriCore
import SwiftUI

struct SignInView: View {
    let prompt: SignInDestination.Prompt
    let status: SignInStatus
    let onAppleResult: (AppleSignInResult) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 文字を大きくして入りきらないときは、サインインのボタンをいつも画面の下に見せるため、見出しと同意の文だけを送る
            ViewThatFits(in: .vertical) {
                introduction
                    .frame(maxHeight: .infinity)
                ScrollView {
                    introduction
                }
            }
            VStack(spacing: 12) {
                statusLine
                    // 下に残す欄では送る側より先に縮められるので、文字を大きくしても文を途中で切らない
                    .fixedSize(horizontal: false, vertical: true)
                AppleSignInButton(onResult: onAppleResult)
                    .disabled(status == .signingIn)
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signIn")
    }

    private var introduction: some View {
        VStack(spacing: 24) {
            header
                .frame(maxHeight: .infinity)
            SignInConsentCard()
        }
        .padding([.horizontal, .top])
    }

    @ViewBuilder private var statusLine: some View {
        switch status {
        case .ready:
            EmptyView()
        case .signingIn:
            HStack {
                ProgressView()
                Text("サインインしています…")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let reason):
            Text(failureMessage(for: reason))
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            appMark
            Text("nu-tori")
                .font(.title2.bold())
            Text(lead)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var appMark: some View {
        Image("AppMark")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 13))
            .accessibilityHidden(true)
    }

    private var lead: String {
        switch prompt {
        case .introduction:
            "毎朝の体重と、食事の写真だけ。"
        case .signInAgain(hasPendingWrites: false):
            "もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻ります。"
        case .signInAgain(hasPendingWrites: true):
            "もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻り、まだ送っていない記録も送ります。"
        }
    }

    private func failureMessage(for reason: AccountSession.SignInOutcome.FailureReason) -> String {
        switch reason {
        case .unreachable:
            "インターネットにつながらないため、サインインできませんでした。つながるところで、もう一度押してください。"
        case .other:
            "サインインできませんでした。もう一度押してください。"
        }
    }
}
