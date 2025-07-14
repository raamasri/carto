//
//  StartupView.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/16/25.
//
//  DESCRIPTION:
//  This file contains the startup/onboarding interface for Project Columbus (Carto).
//  It presents users with a visually appealing login/signup interface featuring
//  motion-based parallax effects and animated text introduction.
//
//  COMPONENTS:
//  - MotionManager: Handles device motion for parallax effects
//  - StartupView: Main startup interface with login/signup options
//
//  FEATURES:
//  - Motion-based parallax background effects
//  - Animated text introduction
//  - Smooth transitions and material design
//  - Sheet-based login/signup presentation
//

import SwiftUI
import CoreMotion

// MARK: - Motion Management

/**
 * MotionManager
 * 
 * A class that manages device motion detection for creating parallax effects.
 * This class uses CoreMotion to track device orientation and attitude changes,
 * providing real-time motion data for creating engaging UI animations.
 * 
 * FUNCTIONALITY:
 * - Monitors device roll and pitch in real-time
 * - Updates at 60 FPS for smooth animation
 * - Publishes motion data to SwiftUI views
 * - Handles motion data safely with error checking
 */
class MotionManager: ObservableObject {
    /// CoreMotion manager for device motion detection
    private var motionManager = CMMotionManager()
    
    /// Published roll value for horizontal motion effects
    @Published var x = 0.0
    
    /// Published pitch value for vertical motion effects  
    @Published var y = 0.0

    /**
     * Initializes the motion manager and starts motion updates
     * Sets up 60 FPS motion tracking for smooth parallax effects
     */
    init() {
        // Set update interval to 60 FPS for smooth motion
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        
        // Start device motion updates on main queue
        motionManager.startDeviceMotionUpdates(to: .main) { (data, error) in
            // Safely unwrap motion data
            guard let data = data else { return }
            
            // Update published motion values
            self.x = data.attitude.roll
            self.y = data.attitude.pitch
        }
    }
}

// MARK: - Startup Interface

/**
 * StartupView
 * 
 * The main startup/onboarding view that serves as the entry point for unauthenticated users.
 * This view provides a visually compelling introduction to the app with motion-based
 * parallax effects and clear login/signup options.
 * 
 * DESIGN FEATURES:
 * - Background image with subtle blur effect
 * - Motion-based parallax animations
 * - Animated text introduction
 * - Material design buttons with transparency
 * - Smooth fade-in animations
 * - Sheet-based login/signup presentation
 * 
 * ACCESSIBILITY:
 * - High contrast text and buttons
 * - Clear visual hierarchy
 * - Semantic button labels
 * - Proper sheet presentation
 */
struct StartupView: View {
    // MARK: - Environment Objects
    
    /// Authentication manager for handling user login/signup
    @EnvironmentObject var authManager: AuthManager
    
    /// Motion manager for parallax effects
    @StateObject private var motion = MotionManager()

    // MARK: - View State
    
    /// Controls display of login sheet
    @State private var showLogin = false
    
    /// Controls display of signup sheet
    @State private var showSignup = false
    
    /// Current animated text being displayed
    @State private var animatedText = ""
    
    /// Overall view opacity for fade-in effect
    @State private var opacity = 0.0

    // MARK: - View Body
    
    var body: some View {
        ZStack {
            // Background image with blur effect
            Image("valleypic")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: 0.5) // Subtle blur for text readability
            
            VStack {
                Spacer()
                
                // Animated app title with motion parallax
                Text(animatedText)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(Color.white.opacity(0.8))
                    .foregroundStyle(.ultraThinMaterial)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 50)
                    .padding(.top, 300)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Apply motion-based offset for parallax effect
                    .offset(x: motion.x * 20, y: motion.y * 20)
                    .onAppear {
                        // Animate text appearance character by character
                        let fullText = "CARTO"
                        animatedText = ""
                        for (index, character) in fullText.enumerated() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                                animatedText.append(character)
                            }
                        }
                    }

                Spacer()

                // Authentication buttons section
                VStack(spacing: 15) {
                    // Login button with material design
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

                    // Sign up button with solid background
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
                // Apply inverse motion for subtle countermovement
                .offset(x: motion.x * -10, y: motion.y * -10)
            }
            .frame(maxHeight: .infinity)
            .opacity(opacity)
            // Animate view appearance
            .onAppear {
                withAnimation(.easeIn(duration: 1.0)) {
                    opacity = 1
                }
            }
            // Present login sheet when requested
            .sheet(isPresented: $showLogin) {
                LoginView()
                    .environmentObject(authManager)
            }
            // Present signup sheet when requested
            .sheet(isPresented: $showSignup) {
                SignUpView()
                    .environmentObject(authManager)
            }
        }
    }
}
