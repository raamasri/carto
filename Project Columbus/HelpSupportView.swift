//
//  HelpSupportView.swift
//  Project Columbus
//
//  Created by AI Assistant on 1/7/25.
//

import SwiftUI
import UIKit

struct HelpSupportView: View {
    @State private var showingContactForm = false
    @State private var showingMailComposer = false
    @State private var searchText = ""
    @State private var selectedCategory: SupportCategory = .general
    
    var body: some View {
        NavigationView {
            List {
                // Quick Actions Section
                Section(header: Text("Get Help")) {
                    NavigationLink(destination: ContactSupportView()) {
                        HelpActionRow(
                            icon: "message.fill",
                            title: "Contact Support",
                            description: "Get help from our support team",
                            accentColor: .blue
                        )
                    }
                    
                    NavigationLink(destination: ReportBugView()) {
                        HelpActionRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Report a Bug",
                            description: "Let us know about issues you've found",
                            accentColor: .orange
                        )
                    }
                    
                    NavigationLink(destination: FeatureRequestView()) {
                        HelpActionRow(
                            icon: "lightbulb.fill",
                            title: "Request a Feature",
                            description: "Suggest new features for CARTO",
                            accentColor: .yellow
                        )
                    }
                    
                    NavigationLink(destination: AppTutorialView()) {
                        HelpActionRow(
                            icon: "play.circle.fill",
                            title: "App Tutorial",
                            description: "Learn how to use CARTO",
                            accentColor: .green
                        )
                    }
                }
                
                // FAQ Section
                Section(header: Text("Frequently Asked Questions")) {
                    ForEach(filteredFAQs, id: \.id) { faq in
                        NavigationLink(destination: FAQDetailView(faq: faq)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(faq.question)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(faq.category.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                // Community Section
                Section(header: Text("Community")) {
                    Button(action: openCommunityForum) {
                        HelpActionRow(
                            icon: "person.3.fill",
                            title: "Community Forum",
                            description: "Connect with other CARTO users",
                            accentColor: .purple
                        )
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: openDiscord) {
                        HelpActionRow(
                            icon: "message.badge.fill",
                            title: "Discord Server",
                            description: "Join our Discord community",
                            accentColor: .indigo
                        )
                    }
                    .foregroundColor(.primary)
                }
                
                // Documentation Section
                Section(header: Text("Documentation")) {
                    NavigationLink(destination: UserGuideView()) {
                        HelpActionRow(
                            icon: "book.fill",
                            title: "User Guide",
                            description: "Complete guide to using CARTO",
                            accentColor: .brown
                        )
                    }
                    
                    NavigationLink(destination: APIDocumentationView()) {
                        HelpActionRow(
                            icon: "doc.text.fill",
                            title: "API Documentation",
                            description: "For developers integrating with CARTO",
                            accentColor: .gray
                        )
                    }
                }
                
                // Contact Information
                Section(header: Text("Contact Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("support@carto.app")
                                .font(.body)
                        }
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            Text("Response time: Within 24 hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.purple)
                                .frame(width: 20)
                            Text("Available 24/7")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search help topics...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(SupportCategory.allCases, id: \.self) { category in
                            Button(category.displayName) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
    
    private var filteredFAQs: [FAQ] {
        let categoryFiltered = selectedCategory == .general ? sampleFAQs : sampleFAQs.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { faq in
                faq.question.localizedCaseInsensitiveContains(searchText) ||
                faq.answer.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func openCommunityForum() {
        if let url = URL(string: "https://community.carto.app") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openDiscord() {
        if let url = URL(string: "https://discord.gg/carto") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct HelpActionRow: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ContactSupportView: View {
    @State private var subject = ""
    @State private var message = ""
    @State private var selectedCategory: SupportCategory = .general
    @State private var userEmail = ""
    @State private var showingSubmissionAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Information")) {
                    TextField("Your Email", text: $userEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("Issue Details")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(SupportCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    
                    TextField("Subject", text: $subject)
                    
                    TextField("Describe your issue...", text: $message, axis: .vertical)
                        .lineLimit(5...10)
                }
                
                Section {
                    Button("Submit Request") {
                        submitSupportRequest()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(subject.isEmpty || message.isEmpty || userEmail.isEmpty)
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Request Submitted", isPresented: $showingSubmissionAlert) {
                Button("OK") { }
            } message: {
                Text("Your support request has been submitted. We'll get back to you within 24 hours.")
            }
        }
    }
    
    private func submitSupportRequest() {
        Task {
            let success = await sendSupportRequest()
            
            await MainActor.run {
                if success {
                    showingSubmissionAlert = true
                    // Reset form
                    subject = ""
                    description = ""
                    selectedCategory = .general
                } else {
                    // Show error alert
                    showingSubmissionAlert = true
                }
            }
        }
    }
    
    private func sendSupportRequest() async -> Bool {
        do {
            // Simulate API call
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
            
            let ticketId = "TICKET-\(Int.random(in: 10000...99999))"
            
            print("📧 Support request submitted:")
            print("  - Ticket ID: \(ticketId)")
            print("  - Category: \(selectedCategory.rawValue)")
            print("  - Subject: \(subject)")
            print("  - Description: \(description)")
            
            return true
        } catch {
            print("❌ Error submitting support request: \(error)")
            return false
        }
    }
}

struct ReportBugView: View {
    @State private var bugDescription = ""
    @State private var stepsToReproduce = ""
    @State private var deviceInfo = UIDevice.current.systemVersion
    @State private var appVersion = "0.64.0"
    @State private var showingSubmissionAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bug Description")) {
                    TextField("Describe the bug...", text: $bugDescription, axis: .vertical)
                        .lineLimit(3...8)
                }
                
                Section(header: Text("Steps to Reproduce")) {
                    TextField("How can we reproduce this bug?", text: $stepsToReproduce, axis: .vertical)
                        .lineLimit(3...8)
                }
                
                Section(header: Text("Device Information")) {
                    HStack {
                        Text("iOS Version")
                        Spacer()
                        Text(deviceInfo)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Submit Bug Report") {
                        submitBugReport()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(bugDescription.isEmpty)
                }
            }
            .navigationTitle("Report Bug")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Bug Report Submitted", isPresented: $showingSubmissionAlert) {
                Button("OK") { }
            } message: {
                Text("Thank you for your bug report! We'll investigate and get back to you soon.")
            }
        }
    }
    
    private func submitBugReport() {
        Task {
            let success = await sendBugReport()
            
            await MainActor.run {
                if success {
                    showingSubmissionAlert = true
                    // Reset form
                    bugDescription = ""
                    stepsToReproduce = ""
                }
            }
        }
    }
    
    private func sendBugReport() async -> Bool {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            let reportId = "BUG-\(Int.random(in: 10000...99999))"
            
            print("🐛 Bug report submitted:")
            print("  - Report ID: \(reportId)")
            print("  - Description: \(bugDescription)")
            print("  - Steps: \(stepsToReproduce)")
            print("  - Device: iOS \(deviceInfo)")
            print("  - App Version: \(appVersion)")
            
            return true
        } catch {
            print("❌ Error submitting bug report: \(error)")
            return false
        }
    }
}

struct FeatureRequestView: View {
    @State private var featureTitle = ""
    @State private var featureDescription = ""
    @State private var useCase = ""
    @State private var showingSubmissionAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Feature Request")) {
                    TextField("Feature Title", text: $featureTitle)
                    
                    TextField("Describe the feature...", text: $featureDescription, axis: .vertical)
                        .lineLimit(3...8)
                }
                
                Section(header: Text("Use Case")) {
                    TextField("How would you use this feature?", text: $useCase, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Submit Feature Request") {
                        submitFeatureRequest()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(featureTitle.isEmpty || featureDescription.isEmpty)
                }
            }
            .navigationTitle("Feature Request")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Feature Request Submitted", isPresented: $showingSubmissionAlert) {
                Button("OK") { }
            } message: {
                Text("Thank you for your feature request! We'll review it and consider it for future updates.")
            }
        }
    }
    
    private func submitFeatureRequest() {
        Task {
            let success = await sendFeatureRequest()
            
            await MainActor.run {
                if success {
                    showingSubmissionAlert = true
                    // Reset form
                    featureTitle = ""
                    featureDescription = ""
                    useCase = ""
                }
            }
        }
    }
    
    private func sendFeatureRequest() async -> Bool {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            let requestId = "FEATURE-\(Int.random(in: 10000...99999))"
            
            print("💡 Feature request submitted:")
            print("  - Request ID: \(requestId)")
            print("  - Title: \(featureTitle)")
            print("  - Description: \(featureDescription)")
            print("  - Use Case: \(useCase)")
            
            return true
        } catch {
            print("❌ Error submitting feature request: \(error)")
            return false
        }
    }
}

struct AppTutorialView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Getting Started")) {
                    NavigationLink("Creating Your First Pin", destination: TutorialDetailView(title: "Creating Your First Pin", content: "To create a new pin, tap and hold on any location on the map. A pin will appear, and you can then add details like a name, description, and assign it to a list."))
                    NavigationLink("Exploring the Map", destination: TutorialDetailView(title: "Exploring the Map", content: "Use pinch gestures to zoom in and out. Tap and drag to move around the map. Switch between map types in Settings."))
                    NavigationLink("Setting Up Your Profile", destination: TutorialDetailView(title: "Setting Up Your Profile", content: "Go to your profile tab to add a photo, bio, and customize your account settings."))
                }
                
                Section(header: Text("Advanced Features")) {
                    NavigationLink("Creating Lists", destination: TutorialDetailView(title: "Creating Lists", content: "Organize your pins into custom lists. Go to the Lists tab and tap the + button to create a new list."))
                    NavigationLink("Sharing with Friends", destination: TutorialDetailView(title: "Sharing with Friends", content: "Share your favorite places with friends by making lists public or sending them directly."))
                    NavigationLink("Privacy Settings", destination: TutorialDetailView(title: "Privacy Settings", content: "Control who can see your activity by adjusting privacy settings in your account preferences."))
                }
            }
            .navigationTitle("App Tutorial")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct TutorialDetailView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(content)
                    .font(.body)
                
                // TODO: Add actual tutorial content with images and step-by-step instructions
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct FAQDetailView: View {
    let faq: FAQ
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(faq.question)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(faq.answer)
                    .font(.body)
                
                if !faq.relatedLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related Links")
                            .font(.headline)
                        
                        ForEach(faq.relatedLinks, id: \.title) { link in
                            Button(link.title) {
                                if let url = URL(string: link.url) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UserGuideView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Basics") {
                    NavigationLink("Getting Started", destination: TutorialDetailView(title: "Getting Started", content: "Welcome to CARTO! This guide will help you get started..."))
                    NavigationLink("Navigation", destination: TutorialDetailView(title: "Navigation", content: "Learn how to navigate the app..."))
                }
                
                Section("Features") {
                    NavigationLink("Pins & Lists", destination: TutorialDetailView(title: "Pins & Lists", content: "Master the art of organizing locations..."))
                    NavigationLink("Social Features", destination: TutorialDetailView(title: "Social Features", content: "Connect with friends and share experiences..."))
                }
                
                Section("Advanced") {
                    NavigationLink("Privacy & Security", destination: TutorialDetailView(title: "Privacy & Security", content: "Keep your data safe and secure..."))
                    NavigationLink("Troubleshooting", destination: TutorialDetailView(title: "Troubleshooting", content: "Common issues and solutions..."))
                }
            }
            .navigationTitle("User Guide")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct APIDocumentationView: View {
    var body: some View {
        NavigationView {
            List {
                Section("API Overview") {
                    NavigationLink("Authentication", destination: TutorialDetailView(title: "Authentication", content: "Learn how to authenticate with the CARTO API..."))
                    NavigationLink("Rate Limits", destination: TutorialDetailView(title: "Rate Limits", content: "Understanding API rate limits..."))
                }
                
                Section("Endpoints") {
                    NavigationLink("Pins API", destination: TutorialDetailView(title: "Pins API", content: "Manage pins programmatically..."))
                    NavigationLink("Users API", destination: TutorialDetailView(title: "Users API", content: "User management endpoints..."))
                }
            }
            .navigationTitle("API Documentation")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Models

enum SupportCategory: String, CaseIterable {
    case general = "general"
    case account = "account"
    case technical = "technical"
    case billing = "billing"
    case privacy = "privacy"
    case features = "features"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .account: return "Account"
        case .technical: return "Technical"
        case .billing: return "Billing"
        case .privacy: return "Privacy"
        case .features: return "Features"
        }
    }
}

struct FAQ {
    let id = UUID()
    let question: String
    let answer: String
    let category: SupportCategory
    let relatedLinks: [RelatedLink]
}

struct RelatedLink {
    let title: String
    let url: String
}

// Sample FAQ data
let sampleFAQs: [FAQ] = [
    FAQ(
        question: "How do I create a new pin?",
        answer: "To create a new pin, tap and hold on any location on the map. A pin will appear, and you can then add details like a name, description, and assign it to a list.",
        category: .general,
        relatedLinks: [
            RelatedLink(title: "Pin Creation Guide", url: "https://help.carto.app/pins/create")
        ]
    ),
    FAQ(
        question: "How do I make my account private?",
        answer: "Go to Settings > Account and toggle 'Private Account'. When your account is private, only approved followers can see your pins and activity.",
        category: .privacy,
        relatedLinks: [
            RelatedLink(title: "Privacy Settings Guide", url: "https://help.carto.app/privacy")
        ]
    ),
    FAQ(
        question: "Can I export my data?",
        answer: "Yes! Go to Settings > Data & Storage > Export Data. You can export your pins, lists, and other data in JSON format.",
        category: .account,
        relatedLinks: []
    ),
    FAQ(
        question: "Why isn't my location updating?",
        answer: "Make sure location permissions are enabled for CARTO in your device settings. Also check that 'Show My Location' is enabled in Settings > Map Preferences.",
        category: .technical,
        relatedLinks: [
            RelatedLink(title: "Location Troubleshooting", url: "https://help.carto.app/location")
        ]
    )
]

#Preview {
    HelpSupportView()
} 