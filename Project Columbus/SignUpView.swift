import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showBuildProfile = false

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("Join Cart-o")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)

                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .background(Color.white)
                    .cornerRadius(8)

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .background(Color.white)
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .background(Color.white)
                    .cornerRadius(8)

                Button("Sign Up") {
                    if !username.isEmpty && !email.isEmpty && !password.isEmpty {
                        showBuildProfile = true
                    }
                }
                .sheet(isPresented: $showBuildProfile) {
                    BuildProfileView()
                        .environmentObject(authManager)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            }
            .padding()
        }
    }
}

// LoginView should be defined in LoginView.swift only.
