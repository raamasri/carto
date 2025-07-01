//
//  PrivacyPolicyView.swift
//  Project Columbus
//
//  Created by AI Assistant on 1/7/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Last updated: January 7, 2025")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Effective date: January 7, 2025")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Introduction
                    PrivacySection(
                        title: "Introduction",
                        content: """
                        Welcome to CARTO ("we," "our," or "us"). We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and protect your information when you use our location-based social networking app.
                        
                        By using CARTO, you agree to the collection and use of information in accordance with this policy.
                        """
                    )
                    
                    // Information We Collect
                    PrivacySection(
                        title: "Information We Collect",
                        content: """
                        We collect several types of information:
                        
                        • Location Data: We collect your precise location when you use the app to create pins and discover nearby places. You can control location sharing in your device settings.
                        
                        • Account Information: When you create an account, we collect your username, email address, and any profile information you provide.
                        
                        • User Content: We store the pins, lists, comments, and other content you create within the app.
                        
                        • Usage Data: We collect information about how you use the app, including features accessed and time spent.
                        
                        • Device Information: We may collect device identifiers, operating system version, and app version for technical support.
                        """
                    )
                    
                    // How We Use Your Information
                    PrivacySection(
                        title: "How We Use Your Information",
                        content: """
                        We use your information to:
                        
                        • Provide and maintain our service
                        • Show you relevant locations and content
                        • Enable social features like sharing with friends
                        • Send you important updates about your account
                        • Improve our app and develop new features
                        • Ensure security and prevent fraud
                        • Comply with legal obligations
                        
                        We will never sell your personal data to third parties.
                        """
                    )
                    
                    // Information Sharing
                    PrivacySection(
                        title: "Information Sharing",
                        content: """
                        We may share your information in the following circumstances:
                        
                        • With Other Users: When you make content public or share with friends, as controlled by your privacy settings.
                        
                        • Service Providers: We may share data with trusted third-party services that help us operate the app (analytics, cloud storage, etc.).
                        
                        • Legal Requirements: We may disclose information if required by law or to protect our rights and users' safety.
                        
                        • Business Transfers: In the event of a merger or acquisition, user data may be transferred as part of the business assets.
                        """
                    )
                    
                    // Your Privacy Controls
                    PrivacySection(
                        title: "Your Privacy Controls",
                        content: """
                        You have control over your privacy:
                        
                        • Account Privacy: Make your account private so only approved followers can see your content.
                        
                        • Location Sharing: Control when and how your location is shared through device settings and app preferences.
                        
                        • Data Access: Request a copy of your data at any time through Settings > Account > Export Data.
                        
                        • Data Deletion: Delete your account and associated data through Settings > Account > Delete Account.
                        
                        • Communication Preferences: Control what notifications and emails you receive.
                        """
                    )
                    
                    // Data Security
                    PrivacySection(
                        title: "Data Security",
                        content: """
                        We implement appropriate security measures to protect your personal data:
                        
                        • Encryption in transit and at rest
                        • Regular security audits and updates
                        • Access controls and authentication
                        • Secure cloud infrastructure
                        
                        However, no method of transmission over the internet is 100% secure. We cannot guarantee absolute security but strive to use commercially acceptable means to protect your data.
                        """
                    )
                    
                    // Children's Privacy
                    PrivacySection(
                        title: "Children's Privacy",
                        content: """
                        CARTO is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us so we can delete such information.
                        """
                    )
                    
                    // International Data Transfers
                    PrivacySection(
                        title: "International Data Transfers",
                        content: """
                        Your information may be transferred to and processed in countries other than your own. We ensure that such transfers comply with applicable data protection laws and that your data receives adequate protection.
                        """
                    )
                    
                    // Changes to This Policy
                    PrivacySection(
                        title: "Changes to This Policy",
                        content: """
                        We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy in the app and updating the "Last updated" date. Continued use of the app after changes constitutes acceptance of the new policy.
                        """
                    )
                    
                    // Contact Us
                    PrivacySection(
                        title: "Contact Us",
                        content: """
                        If you have any questions about this privacy policy or our data practices, please contact us:
                        
                        Email: privacy@carto.app
                        Address: CARTO Inc., Privacy Team
                        
                        For data protection inquiries in the EU, you may also contact our Data Protection Officer at dpo@carto.app.
                        """
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search privacy policy...")
        }
    }
}

struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .lineSpacing(2)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
} 