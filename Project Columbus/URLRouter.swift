//
//  URLRouter.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI
import Foundation

// MARK: - Deep Link Types
enum DeepLinkDestination {
    case profile(username: String)
    case pin(id: String)
    case list(id: String)
    case unknown
}

// MARK: - URL Router
class URLRouter: ObservableObject {
    @Published var currentDestination: DeepLinkDestination?
    @Published var shouldNavigateToProfile = false
    @Published var targetUsername: String?
    
    func handleURL(_ url: URL) {
        print("🔗 URLRouter: Handling incoming URL: \(url)")
        
        guard url.host == "carto.app" else {
            print("🔗 URLRouter: Invalid host: \(url.host ?? "nil")")
            return
        }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        print("🔗 URLRouter: Path components: \(pathComponents)")
        
        guard pathComponents.count >= 2 else {
            print("🔗 URLRouter: Invalid path structure")
            return
        }
        
        let type = pathComponents[0]
        let identifier = pathComponents[1]
        
        switch type {
        case "profile":
            print("🔗 URLRouter: Navigating to profile: \(identifier)")
            handleProfileDeepLink(username: identifier)
        case "pin":
            print("🔗 URLRouter: Navigating to pin: \(identifier)")
            currentDestination = .pin(id: identifier)
        case "list":
            print("🔗 URLRouter: Navigating to list: \(identifier)")
            currentDestination = .list(id: identifier)
        default:
            print("🔗 URLRouter: Unknown deep link type: \(type)")
            currentDestination = .unknown
        }
    }
    
    private func handleProfileDeepLink(username: String) {
        targetUsername = username
        shouldNavigateToProfile = true
        currentDestination = .profile(username: username)
    }
    
    func resetNavigation() {
        shouldNavigateToProfile = false
        targetUsername = nil
        currentDestination = nil
    }
}

// MARK: - Deep Link View Modifier
struct DeepLinkHandler: ViewModifier {
    @StateObject private var urlRouter = URLRouter()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @State private var targetUser: AppUser?
    @State private var isLoadingUser = false
    
    func body(content: Content) -> some View {
        content
            .environmentObject(urlRouter)
            .onOpenURL { url in
                urlRouter.handleURL(url)
            }
            .onChange(of: urlRouter.shouldNavigateToProfile) { _, shouldNavigate in
                if shouldNavigate, let username = urlRouter.targetUsername {
                    loadUserAndNavigate(username: username)
                }
            }
            .sheet(item: Binding<DeepLinkDestination?>(
                get: { urlRouter.currentDestination },
                set: { _ in urlRouter.resetNavigation() }
            )) { destination in
                switch destination {
                case .profile(let username):
                    if let user = targetUser {
                        UserProfileView(profileUser: user)
                            .environmentObject(authManager)
                            .environmentObject(pinStore)
                    } else if isLoadingUser {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading profile...")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("User not found")
                                .font(.headline)
                            Text("The profile @\(username) could not be found.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Close") {
                                urlRouter.resetNavigation()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                    }
                case .pin, .list, .unknown:
                    VStack(spacing: 16) {
                        Image(systemName: "link")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Coming Soon")
                            .font(.headline)
                        Text("This type of deep link is not yet supported.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Close") {
                            urlRouter.resetNavigation()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
    }
    
    private func loadUserAndNavigate(username: String) {
        guard !isLoadingUser else { return }
        
        isLoadingUser = true
        targetUser = nil
        
        Task {
            do {
                let user = try await SupabaseManager.shared.getUserByUsername(username)
                await MainActor.run {
                    targetUser = user
                    isLoadingUser = false
                }
            } catch {
                print("🔗 Error loading user \(username): \(error)")
                await MainActor.run {
                    isLoadingUser = false
                }
            }
        }
    }
}

// MARK: - DeepLinkDestination Identifiable
extension DeepLinkDestination: Identifiable {
    var id: String {
        switch self {
        case .profile(let username):
            return "profile-\(username)"
        case .pin(let id):
            return "pin-\(id)"
        case .list(let id):
            return "list-\(id)"
        case .unknown:
            return "unknown"
        }
    }
}

// MARK: - View Extension
extension View {
    func withDeepLinkHandling() -> some View {
        modifier(DeepLinkHandler())
    }
} 