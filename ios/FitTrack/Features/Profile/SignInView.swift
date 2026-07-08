import SwiftUI
import AuthenticationServices

/// Optional — signing in only unlocks cross-device sync (Phase 2). The
/// app is fully usable without ever visiting this screen (PLAN.md's
/// offline-first requirement).
struct SignInView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case register = "Create Account"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleResult(result)
                    }
                    .frame(minHeight: 44)
                    .listRowInsets(EdgeInsets())
                    .padding(Theme.Spacing.xs)
                }

                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if mode == .register {
                        TextField("Display name", text: $displayName)
                    }
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.error)
                    }

                    Button(mode.rawValue) {
                        Task { await submitEmailFlow() }
                    }
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            errorMessage = "Sign in with Apple failed."
            return
        }

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await container.auth.signInWithApple(identityToken: identityToken, displayName: name.isEmpty ? nil : name)
                dismiss()
            } catch {
                errorMessage = "Sign in with Apple failed. Please try again."
            }
        }
    }

    private func submitEmailFlow() async {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        do {
            switch mode {
            case .signIn:
                try await container.auth.login(email: email, password: password)
            case .register:
                try await container.auth.register(email: email, password: password, displayName: displayName.isEmpty ? "FitTrack User" : displayName)
            }
            dismiss()
        } catch {
            errorMessage = "Something went wrong. Check your details and try again."
        }
    }
}

#Preview {
    SignInView()
        .environment(AppContainer())
}
