import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var usernameFocused: Bool
    @FocusState private var passwordFocused: Bool

    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""

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

                TextField("@carto", text: $username)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .focused($usernameFocused)
                    .submitLabel(.next)
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
                    .onSubmit {
                        if username.isEmpty || password.isEmpty {
                            errorMessage = "Please enter both username and password."
                            showError = true
                        } else {
                            authManager.logIn(username: username, password: password)
                            presentationMode.wrappedValue.dismiss()
                        }
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
                    if username.isEmpty || password.isEmpty {
                        errorMessage = "Please enter both username and password."
                        showError = true
                    } else {
                        authManager.logIn(username: username, password: password)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Log In")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .bold()
                }

                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            // Handle successful authorization
                            print("Apple Sign In successful: \(authorization)")
                        case .failure(let error):
                            // Handle error
                            print("Apple Sign In failed: \(error.localizedDescription)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 45)
                .cornerRadius(10)
            }
            .padding()
        }
    }
}
