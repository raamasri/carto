//
//  SettingsView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//
import SwiftUI
import MapKit
import Combine
import Foundation

struct SettingsView: View {
    @Environment(\.presentationMode) var dismiss
    @AppStorage("themePreference") private var themePreference: String = "Auto"
    @AppStorage("selectedMapType") private var selectedMapType: String = "Standard"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    NavigationLink("Edit Profile", destination: Text("Profile Editor Placeholder"))
                    NavigationLink("Change Password", destination: Text("Password Change Placeholder"))
                    NavigationLink("Connected Accounts", destination: Text("Connected Accounts Placeholder"))
                    Toggle("Private Account", isOn: .constant(false))
                }
                
                Section(header: Text("Map Preferences")) {
                    Picker("Map Type", selection: $selectedMapType) {
                        Text("Standard").tag("Standard")
                        Text("Satellite").tag("Satellite")
                        Text("Hybrid").tag("Hybrid")
                    }
                    Toggle("Show My Location", isOn: .constant(true))
                    Toggle("Show Reactions", isOn: .constant(true))
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Friend Activity", isOn: .constant(true))
                    Toggle("Nearby Pins", isOn: .constant(true))
                    Toggle("New Followers", isOn: .constant(false))
                    Toggle("Event Reminders", isOn: .constant(true))
                    Toggle("Product Updates", isOn: .constant(false))
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themePreference) {
                        Text("Auto").tag("Auto")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                }
                
                Section(header: Text("Data & Storage")) {
                    Toggle("Use Cellular Data", isOn: .constant(true))
                    Button("Clear Cache") {
                        // Placeholder for cache clearing logic
                    }
                }
                
                Section(header: Text("About")) {
                    NavigationLink("Help & Support", destination: Text("Help Placeholder"))
                    NavigationLink("Privacy Policy", destination: Text("Privacy Placeholder"))
                    NavigationLink("Terms of Use", destination: Text("Terms Placeholder"))
                    Text("App Version 1.0.0")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
