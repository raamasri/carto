import SwiftUI

struct StartupView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var showLogin = false
    @State private var showSignup = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Welcome to Cart-o")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)

                Button("Log In") {
                    showLogin.toggle()
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button("Join Now") {
                    showSignup.toggle()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showSignup) {
                SignUpView()
                    .environmentObject(authManager)
            }
            .padding()
        }
    }
}
