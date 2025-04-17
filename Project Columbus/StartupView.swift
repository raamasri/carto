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
                    .padding(.horizontal, 50)
                    .padding(.top, 300)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: motion.x * 30, y: motion.y * 60)
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
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .cornerRadius(15)
                            .frame(height: 50)

                        Button(action: {
                            showLogin.toggle()
                        }) {
                            Text("Log In")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.white)
                                .background(Color.clear)
                                .cornerRadius(15)
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button(action: {
                        showSignup.toggle()
                    }) {
                        Text("Sign Up")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(15)
                            .bold()
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
                .offset(x: motion.x * -10, y: motion.y * -10)
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
