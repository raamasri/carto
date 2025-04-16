import SwiftUI
import CoreMotion

class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var x = 0.0
    @Published var y = 0.0

    init() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { (data, error) in
            guard let data = data else { return }
            self.x = data.attitude.roll
            self.y = data.attitude.pitch
        }
    }
}

struct StartupView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var motion = MotionManager()

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
                    .offset(x: motion.x * 30, y: motion.y * 30)
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
                .offset(x: motion.x * -30, y: motion.y * -30)
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
