import NuToriCore
import Observation

@Observable
final class RootModel {
    private(set) var screen: Screen = .opening

    init(accountSession: AccountSession, recordSync: RecordSync) {
        self.accountSession = accountSession
        self.recordSync = recordSync
        recordSync.onDestination = { [weak self] destination in
            self?.screen = Screen(destination)
        }
    }

    func open() async {
        do {
            screen = Screen(try await accountSession.destinationOnOpen())
        } catch is CancellationError {
            return
        } catch {
            screen = .signIn(.introduction, .ready)
        }
        await syncIfShowingTimeline()
    }

    /// Apple ID の設定で連携を止めたあと、アプリを終了せずに戻った人にも、サインインの画面を出すため
    func reopenIfSignedIn() async {
        switch screen {
        case .loadingTimeline, .timeline:
            await open()
        case .opening, .signIn:
            return
        }
    }

    func signIn(with result: AppleSignInResult) async {
        guard case .signIn(let prompt, _) = screen else { return }
        switch result {
        case .cancelled:
            screen = .signIn(prompt, .ready)
        case .failed:
            screen = .signIn(prompt, .failed(.other))
        case .authorized(let credential):
            screen = .signIn(prompt, .signingIn)
            screen = await signInOutcomeScreen(prompt: prompt, credential: credential)
            await syncIfShowingTimeline()
        }
    }

    enum Screen: Equatable {
        case opening
        case signIn(SignInDestination.Prompt, SignInStatus)
        case loadingTimeline
        case timeline

        init(_ destination: SignInDestination) {
            switch destination {
            case .signIn(let prompt): self = .signIn(prompt, .ready)
            case .loadingTimeline: self = .loadingTimeline
            case .timeline: self = .timeline
            }
        }
    }

    private let accountSession: AccountSession
    private let recordSync: RecordSync

    private func syncIfShowingTimeline() async {
        switch screen {
        case .loadingTimeline, .timeline:
            _ = try? await recordSync.sync()
        case .opening, .signIn:
            return
        }
    }

    private func signInOutcomeScreen(
        prompt: SignInDestination.Prompt,
        credential: AppleSignInCredential
    ) async -> Screen {
        do {
            switch try await accountSession.signIn(with: credential) {
            case .signedIn(let destination): return Screen(destination)
            case .failed(let reason): return .signIn(prompt, .failed(reason))
            }
        } catch {
            return .signIn(prompt, .failed(.other))
        }
    }
}
