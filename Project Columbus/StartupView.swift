import SwiftUI

struct StartupView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var showLogin = false
    @State private var showSignup = false
    @State private var animatedText = ""
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.bottom, 20)

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

                VStack(spacing: 12) {
                    Button("Log In") {
                        showLogin.toggle()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)

                    Button("Join Now") {
                        showSignup.toggle()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .frame(maxHeight: .infinity)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 1.0)) {
                    opacity = 1
                }
            }
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
