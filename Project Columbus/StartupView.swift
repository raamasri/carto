import SwiftUI

struct StartupView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var showLogin = false
    @State private var showSignup = false
    @State private var animatedText = ""
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            Image("valleypic")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 0.5)

            VStack {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 5)
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                Spacer()

                Text(animatedText)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(Color.white.opacity(0.8))
                    .foregroundStyle(.ultraThinMaterial)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        let fullText = "CARTO"
                        animatedText = ""
                        for (index, character) in fullText.enumerated() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                                animatedText.append(character)
                            }
                        }
                    }

                Spacer()

                VStack(spacing: 15) {
                    Button("Log In") {
                        showLogin.toggle()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(15)

                    Button("Sign Up") {
                        showSignup.toggle()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(15)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
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
