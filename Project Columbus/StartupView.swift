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
    @State private var logoScale = 0.8
    @State private var buttonsOffset: CGFloat = 50
    @State private var buttonsOpacity = 0.0

    var body: some View {
        ZStack {
            Image("valleypic")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 1.5)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.3),
                            Color.clear,
                            Color.black.opacity(0.6)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )

            VStack {
                Spacer()
                
                Text(animatedText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color.white.opacity(0.9)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .padding(.top, 200)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(x: motion.x * 15, y: motion.y * 15)
                    .scaleEffect(logoScale)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .onAppear {
                        animateLogoAppearance()
                    }

                Spacer()

                VStack(spacing: 16) {
                    Button(action: {
                        triggerHapticFeedback()
                        showLogin.toggle()
                    }) {
                        HStack {
                            Text("Log In")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(EnhancedButtonStyle())

                    Button(action: {
                        triggerHapticFeedback()
                        showSignup.toggle()
                    }) {
                        HStack {
                            Text("Sign Up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(EnhancedButtonStyle())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .offset(x: motion.x * -8, y: motion.y * -8 + buttonsOffset)
                .opacity(buttonsOpacity)
            }
            .frame(maxHeight: .infinity)
            .opacity(opacity)
            .onAppear {
                animateInitialAppearance()
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
    
    private func animateInitialAppearance() {
        withAnimation(.easeOut(duration: 1.2)) {
            opacity = 1
        }
    }
    
    private func animateLogoAppearance() {
        let fullText = "CARTO"
        animatedText = ""
        
        withAnimation(.spring(response: 1.2, dampingFraction: 0.8, blendDuration: 0)) {
            logoScale = 1.0
        }
        
        for (index, character) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animatedText.append(character)
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(fullText.count) * 0.15 + 0.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                buttonsOffset = 0
                buttonsOpacity = 1
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

struct EnhancedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
