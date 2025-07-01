//
//  TermsOfUseView.swift
//  Project Columbus
//
//  Created by AI Assistant on 1/7/25.
//

import SwiftUI

struct TermsOfUseView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terms of Use")
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
                    TermsSection(
                        title: "Acceptance of Terms",
                        content: """
                        Welcome to CARTO! These Terms of Use ("Terms") govern your use of the CARTO mobile application and related services (collectively, the "Service") operated by CARTO Inc. ("we," "us," or "our").
                        
                        By accessing or using our Service, you agree to be bound by these Terms. If you disagree with any part of these terms, then you may not access the Service.
                        """
                    )
                    
                    // Description of Service
                    TermsSection(
                        title: "Description of Service",
                        content: """
                        CARTO is a location-based social networking platform that allows users to:
                        
                        • Create and share location pins
                        • Organize locations into lists
                        • Connect with friends and share experiences
                        • Discover new places and recommendations
                        • Access location-based content and features
                        
                        The Service is provided "as is" and we reserve the right to modify or discontinue features at any time.
                        """
                    )
                    
                    // User Accounts
                    TermsSection(
                        title: "User Accounts",
                        content: """
                        To use certain features of the Service, you must create an account. You agree to:
                        
                        • Provide accurate and complete information
                        • Maintain the security of your password
                        • Accept responsibility for all activities under your account
                        • Notify us immediately of any unauthorized use
                        
                        You are responsible for safeguarding your account credentials and for all activities that occur under your account.
                        """
                    )
                    
                    // Acceptable Use
                    TermsSection(
                        title: "Acceptable Use",
                        content: """
                        You agree NOT to use the Service to:
                        
                        • Violate any laws or regulations
                        • Infringe on others' intellectual property rights
                        • Harass, abuse, or harm other users
                        • Share false, misleading, or inappropriate content
                        • Attempt to gain unauthorized access to our systems
                        • Interfere with the proper functioning of the Service
                        • Use the Service for commercial purposes without permission
                        • Share private or personal information of others without consent
                        """
                    )
                    
                    // User Content
                    TermsSection(
                        title: "User Content",
                        content: """
                        You retain ownership of content you create and share on CARTO. However, by posting content, you grant us:
                        
                        • A worldwide, non-exclusive license to use, display, and distribute your content
                        • The right to modify content for technical compatibility
                        • Permission to use content for promotional purposes (with attribution)
                        
                        You represent that you have the right to share all content you post and that it doesn't violate these Terms or applicable laws.
                        """
                    )
                    
                    // Privacy and Data
                    TermsSection(
                        title: "Privacy and Data",
                        content: """
                        Your privacy is important to us. Our Privacy Policy explains how we collect, use, and protect your information. By using the Service, you consent to our data practices as described in the Privacy Policy.
                        
                        You understand that the Service involves location sharing and social features that may make certain information visible to other users based on your privacy settings.
                        """
                    )
                    
                    // Intellectual Property
                    TermsSection(
                        title: "Intellectual Property",
                        content: """
                        The Service and its original content, features, and functionality are owned by CARTO Inc. and are protected by international copyright, trademark, and other intellectual property laws.
                        
                        You may not copy, modify, distribute, sell, or lease any part of our Service without explicit written permission.
                        """
                    )
                    
                    // Termination
                    TermsSection(
                        title: "Termination",
                        content: """
                        We may terminate or suspend your account and access to the Service immediately, without prior notice, for conduct that we believe violates these Terms or is harmful to other users, us, or third parties.
                        
                        You may terminate your account at any time through the app settings. Upon termination, your right to use the Service will cease immediately.
                        """
                    )
                    
                    // Disclaimers
                    TermsSection(
                        title: "Disclaimers",
                        content: """
                        The Service is provided "as is" without warranties of any kind. We disclaim all warranties, express or implied, including but not limited to:
                        
                        • Merchantability and fitness for a particular purpose
                        • Accuracy, reliability, or completeness of content
                        • Uninterrupted or error-free operation
                        • Security of data transmission
                        
                        Use of location services involves inherent risks, and you use such features at your own discretion.
                        """
                    )
                    
                    // Limitation of Liability
                    TermsSection(
                        title: "Limitation of Liability",
                        content: """
                        To the maximum extent permitted by law, CARTO Inc. shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data, or use.
                        
                        Our total liability for any claims arising from these Terms or the Service shall not exceed the amount you paid us in the 12 months preceding the claim.
                        """
                    )
                    
                    // Changes to Terms
                    TermsSection(
                        title: "Changes to Terms",
                        content: """
                        We reserve the right to modify these Terms at any time. We will notify users of material changes through the app or email. Continued use of the Service after changes constitutes acceptance of the new Terms.
                        
                        If you disagree with any changes, you must stop using the Service and may delete your account.
                        """
                    )
                    
                    // Governing Law
                    TermsSection(
                        title: "Governing Law",
                        content: """
                        These Terms shall be governed by and construed in accordance with the laws of the State of California, without regard to its conflict of law provisions.
                        
                        Any disputes arising from these Terms or the Service shall be resolved through binding arbitration in accordance with the rules of the American Arbitration Association.
                        """
                    )
                    
                    // Contact Information
                    TermsSection(
                        title: "Contact Us",
                        content: """
                        If you have any questions about these Terms of Use, please contact us:
                        
                        Email: legal@carto.app
                        Address: CARTO Inc., Legal Department
                        
                        For general support inquiries, please use support@carto.app.
                        """
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Terms of Use")
            .searchable(text: $searchText, prompt: "Search terms...")
        }
    }
}

struct TermsSection: View {
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
    TermsOfUseView()
} 