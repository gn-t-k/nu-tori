import NuToriCore
import SwiftUI

struct SignInView: View {
    let prompt: SignInDestination.Prompt
    let status: SignInStatus
    let onAppleResult: (AppleSignInResult) -> Void

    var body: some View {
        // 文字を大きくして入りきらないときだけ、同意の文が切れないよう全体を送れるようにする
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signIn")
    }

    private var content: some View {
        VStack(spacing: 24) {
            header
                .frame(maxHeight: .infinity)
            VStack(spacing: 12) {
                SignInConsentCard()
                statusLine
                AppleSignInButton(onResult: onAppleResult)
                    .disabled(status == .signingIn)
            }
        }
        .padding()
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
