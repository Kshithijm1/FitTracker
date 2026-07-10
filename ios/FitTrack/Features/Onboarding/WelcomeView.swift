import SwiftUI
import AuthenticationServices

/// First screen a new user ever sees. One decision only — how to start —
/// with no forms on screen: Sign in with Apple (one tap), email (sheet),
/// or skip straight in (the app is fully functional offline; an account
/// only adds sync + backend AI fallback).
struct WelcomeView: View {
    /// Called when the user has chosen an entry path; the parent then
    /// advances to the goal questionnaire.
    let onContinue: () -> Void

    @Environment(AppContainer.self) private var container
    @State private var showingEmailSignIn = false
    @State private var appleError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Wordmark + promise, nothing else competing for attention.
            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.Color.accent.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.Color.accent)
                }
                Text("FitTrack")
                    .font(Theme.Font.display34)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text("Workouts, meals, and a coach that\nactually knows you. All in one place.")
                    .font(Theme.Font.body17)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))

                Button {
                    showingEmailSignIn = true
                } label: {
                    Text("Continue with Email")
                        .font(Theme.Font.bodyEmphasized17)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                }

                Button {
                    onContinue()
                } label: {
                    Text("Skip for now")
                        .font(Theme.Font.body17)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(height: 44)
                }

                if let appleError {
                    Text(appleError)
                        .font(Theme.Font.caption13)
                        .foregroundStyle(Theme.Color.error)
                }

                Text("No account needed — everything works on-device.\nAn account adds cross-device sync.")
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Color.background)
        .sheet(isPresented: $showingEmailSignIn) {
            SignInView()
                .onDisappear {
                    if container.auth.isSignedIn { onContinue() }
                }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            appleError = "Sign in with Apple failed — you can still continue without an account."
            return
        }

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        Task {
            do {
                try await container.auth.signInWithApple(
                    identityToken: identityToken,
                    displayName: name.isEmpty ? nil : name
                )
                onContinue()
            } catch {
                appleError = "Sign in with Apple failed — you can still continue without an account."
            }
        }
    }
}
