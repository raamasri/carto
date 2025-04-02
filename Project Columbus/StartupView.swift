import SwiftUI

struct StartupView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var showLogin = false
    @State private var showSignup = false
    @State private var animatedText = ""

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text(animatedText)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .onAppear {
                        let fullText = "WELCOME TO CARTO"
                        animatedText = ""
                        for (index, character) in fullText.enumerated() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                                animatedText.append(character)
                            }
                        }
                    }

                Spacer()

                HStack(spacing: 0) {
                    GeometryReader { geometry in
                        Button("Log In") {
                            showLogin.toggle()
                        }
                        .frame(width: geometry.size.width, height: 60)
                        .contentShape(Rectangle())
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }

                    GeometryReader { geometry in
                        Button("Join Now") {
                            showSignup.toggle()
                        }
                        .frame(width: geometry.size.width, height: 60)
                        .contentShape(Rectangle())
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
                .frame(height: 60)
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            .sheet(isPresented: $showLogin) {
                LoginView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showSignup) {
                SignUpView()
                    .environmentObject(authManager)
            }
        }
    }
}
