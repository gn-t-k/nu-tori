import AuthenticationServices
import SwiftUI

struct AppleSignInButton: View {
    let onResult: (AppleSignInResult) -> Void

    var body: some View {
        #if DEBUG
            if let stubbedResult {
                Button("Appleで続ける") { onResult(stubbedResult) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("appleSignInButton")
            } else {
                appleButton
            }
        #else
            appleButton
        #endif
    }

    @State private var nonce = ""
    @Environment(\.colorScheme) private var colorScheme

    #if DEBUG
        @Environment(\.stubbedAppleSignInResult) private var stubbedResult
    #endif

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            nonce = Self.randomNonce()
            request.requestedScopes = []
            request.nonce = nonce
        } onCompletion: { result in
            onResult(AppleSignInResult(result, nonce: nonce))
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .accessibilityIdentifier("appleSignInButton")
    }

    private static func randomNonce() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
    }
}
