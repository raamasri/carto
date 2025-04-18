import SwiftUI
import AuthenticationServices
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var usernameFocused: Bool
    @FocusState private var passwordFocused: Bool

    @AppStorage("shouldFadeInMap") var shouldFadeInMap = false
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var fadeOut = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                HStack {
                    Text("Welcome Back, Cartographer")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()

                TextField("email", text: $username)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .focused($usernameFocused)
                    .submitLabel(.next)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .onSubmit {
                        passwordFocused = true
                    }
                    .onTapGesture {
                        usernameFocused = true
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !username.isEmpty {
                                Button(action: { username = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    )

                SecureField("password", text: $password)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .focused($passwordFocused)
                    .submitLabel(.go)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        handleLogin()
                    }
                    .onTapGesture {
                        passwordFocused = true
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !password.isEmpty {
                                Button(action: { password = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .padding(.trailing, 10)
                            }
                        }
                    )
                
                Button(action: {
                    handleLogin()
                }) {
                    Text("Log In")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .bold()
                }

                Button(action: {
                    authenticateWithBiometrics()
                }) {
                    HStack {
                        Image(systemName: "faceid") // or "touchid" for older devices
                        Text("Log In with Face ID")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = SupabaseManager.shared.generateNonce()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = SupabaseManager.shared.sha256(nonce)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard
                                let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                let tokenData = appleIDCredential.identityToken,
                                let idToken = String(data: tokenData, encoding: .utf8),
                                let nonce = currentNonce
                            else {
                                print("❌ Failed to get Apple identityToken or nonce")
                                return
                            }

                            Task {
                                do {
                                    let session = try await SupabaseManager.shared.signInWithApple(idToken: idToken, nonce: nonce)
                                    print("✅ Supabase Apple Sign-In success: \(session)")
                                    shouldFadeInMap = true
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        fadeOut = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    }
                                } catch {
                                    print("❌ Supabase Apple Sign-In failed:", error)
                                    errorMessage = "Apple Sign-In failed. Please try again."
                                    showError = true
                                }
                            }

                        case .failure(let error):
                            print("❌ Apple Sign In failed:", error.localizedDescription)
                            errorMessage = "Apple Sign-In authorization failed."
                            showError = true
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 45)
                .cornerRadius(10)
            }
            .padding()
            .opacity(fadeOut ? 0 : 1)
            .onAppear {
                authManager.autoLoginWithBiometricsIfEnabled(successHandler: {
                    shouldFadeInMap = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        fadeOut = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }, errorHandler: { error in
                    errorMessage = error
                    showError = true
                })
            }
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Log in with Face ID / Touch ID"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        handleLogin()
                    } else {
                        errorMessage = "Biometric authentication failed."
                        showError = true
                    }
                }
            }
        } else {
            errorMessage = "Biometric authentication not available."
            showError = true
        }
    }

    private func handleLogin() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both username and password."
            showError = true
            return
        }

        // Clear any previous error
        showError = false

        Task {
            let success = await authManager.logIn(username: username, password: password)

            if success {
                shouldFadeInMap = true
                withAnimation(.easeInOut(duration: 0.3)) {
                    fadeOut = true
                }
                // Allow fade‑out to finish before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } else {
                errorMessage = "Invalid username or password. Please try again."
                showError = true
            }
        }
    }
}
