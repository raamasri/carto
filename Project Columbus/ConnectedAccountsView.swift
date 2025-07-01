//
//  ConnectedAccountsView.swift
//  Project Columbus
//
//  Created by AI Assistant on 1/7/25.
//

import SwiftUI
import AuthenticationServices

struct ConnectedAccountsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var connectedAppleID = false
    @State private var connectedGoogle = false
    @State private var connectedFacebook = false
    @State private var connectedTwitter = false
    @State private var showingDisconnectAlert = false
    @State private var accountToDisconnect: ConnectedAccount?
    @State private var isConnecting = false
    @State private var connectionError: String?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Social Login")) {
                    ConnectedAccountRow(
                        icon: "applelogo",
                        name: "Apple ID",
                        isConnected: connectedAppleID,
                        description: "Sign in with your Apple ID",
                        accentColor: .primary
                    ) {
                        if connectedAppleID {
                            disconnectAccount(.apple)
                        } else {
                            connectAppleID()
                        }
                    }
                    
                    ConnectedAccountRow(
                        icon: "globe",
                        name: "Google",
                        isConnected: connectedGoogle,
                        description: "Connect your Google account",
                        accentColor: .blue
                    ) {
                        if connectedGoogle {
                            disconnectAccount(.google)
                        } else {
                            connectGoogle()
                        }
                    }
                }
                
                Section(header: Text("Social Media"), footer: Text("Connect social media accounts to easily share your favorite locations with friends.")) {
                    ConnectedAccountRow(
                        icon: "person.2.fill",
                        name: "Facebook",
                        isConnected: connectedFacebook,
                        description: "Share pins with Facebook friends",
                        accentColor: .blue
                    ) {
                        if connectedFacebook {
                            disconnectAccount(.facebook)
                        } else {
                            connectFacebook()
                        }
                    }
                    
                    ConnectedAccountRow(
                        icon: "message.fill",
                        name: "Twitter",
                        isConnected: connectedTwitter,
                        description: "Share locations on Twitter",
                        accentColor: .blue
                    ) {
                        if connectedTwitter {
                            disconnectAccount(.twitter)
                        } else {
                            connectTwitter()
                        }
                    }
                }
                
                Section(header: Text("Account Security")) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Two-Factor Authentication")
                                .font(.body)
                            Text("Add an extra layer of security")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Setup") {
                            // TODO: Implement 2FA setup
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Data Sync")) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
                                .font(.body)
                            Text("Sync your data across devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Connected Accounts")
            .navigationBarTitleDisplayMode(.large)
            .alert("Disconnect Account", isPresented: $showingDisconnectAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    if let account = accountToDisconnect {
                        performDisconnect(account)
                    }
                }
            } message: {
                if let account = accountToDisconnect {
                    Text("Are you sure you want to disconnect your \(account.displayName) account? You'll need to reconnect it to use this login method.")
                }
            }
            .overlay {
                if isConnecting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Connecting...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
        }
        .onAppear {
            loadConnectedAccounts()
        }
    }
    
    // MARK: - Connection Methods
    
    private func connectAppleID() {
        isConnecting = true
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        // Note: In a real implementation, you'd set up the delegate properly
        // authorizationController.delegate = self
        // authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        
        // Simulate connection for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            connectedAppleID = true
            isConnecting = false
            saveConnectionState()
        }
    }
    
    private func connectGoogle() {
        isConnecting = true
        
        // TODO: Implement Google Sign-In
        // In a real implementation, you'd use GoogleSignIn framework
        
        // Simulate connection for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            connectedGoogle = true
            isConnecting = false
            saveConnectionState()
        }
    }
    
    private func connectFacebook() {
        isConnecting = true
        
        // TODO: Implement Facebook Login
        // In a real implementation, you'd use Facebook SDK
        
        // Simulate connection for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            connectedFacebook = true
            isConnecting = false
            saveConnectionState()
        }
    }
    
    private func connectTwitter() {
        isConnecting = true
        
        // TODO: Implement Twitter OAuth
        // In a real implementation, you'd use Twitter API
        
        // Simulate connection for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            connectedTwitter = true
            isConnecting = false
            saveConnectionState()
        }
    }
    
    private func disconnectAccount(_ account: ConnectedAccount) {
        accountToDisconnect = account
        showingDisconnectAlert = true
    }
    
    private func performDisconnect(_ account: ConnectedAccount) {
        switch account {
        case .apple:
            connectedAppleID = false
        case .google:
            connectedGoogle = false
        case .facebook:
            connectedFacebook = false
        case .twitter:
            connectedTwitter = false
        }
        saveConnectionState()
    }
    
    // MARK: - Data Persistence
    
    private func loadConnectedAccounts() {
        connectedAppleID = UserDefaults.standard.bool(forKey: "connectedAppleID")
        connectedGoogle = UserDefaults.standard.bool(forKey: "connectedGoogle")
        connectedFacebook = UserDefaults.standard.bool(forKey: "connectedFacebook")
        connectedTwitter = UserDefaults.standard.bool(forKey: "connectedTwitter")
    }
    
    private func saveConnectionState() {
        UserDefaults.standard.set(connectedAppleID, forKey: "connectedAppleID")
        UserDefaults.standard.set(connectedGoogle, forKey: "connectedGoogle")
        UserDefaults.standard.set(connectedFacebook, forKey: "connectedFacebook")
        UserDefaults.standard.set(connectedTwitter, forKey: "connectedTwitter")
    }
}

// MARK: - Supporting Views and Models

struct ConnectedAccountRow: View {
    let icon: String
    let name: String
    let isConnected: Bool
    let description: String
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Button("Disconnect") {
                        action()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Button("Connect") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

enum ConnectedAccount: CaseIterable {
    case apple, google, facebook, twitter
    
    var displayName: String {
        switch self {
        case .apple: return "Apple ID"
        case .google: return "Google"
        case .facebook: return "Facebook"
        case .twitter: return "Twitter"
        }
    }
}

#Preview {
    ConnectedAccountsView()
        .environmentObject(AuthManager())
} 