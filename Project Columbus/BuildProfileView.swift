//
//  BuildProfileView.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/17/25.
//


import SwiftUI

struct BuildProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var profileImage: Image? = nil
    @State private var showImagePicker = false

    let interests = ["Food", "Travel", "Nature", "Art", "Sports", "History"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Build Your Profile")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    // Profile Image Picker
                    ZStack {
                        if let image = profileImage {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .onTapGesture {
                        showImagePicker.toggle()
                    }

                    TextField("Username", text: $username)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)

                    TextField("Bio (optional)", text: $bio)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)

                    Text("Select Your Interests")
                        .foregroundColor(.white)
                        .font(.headline)

                    // Interests Selection
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                        ForEach(interests, id: \.self) { interest in
                            Text(interest)
                                .padding(8)
                                .background(selectedInterests.contains(interest) ? Color.blue : Color.white)
                                .foregroundColor(selectedInterests.contains(interest) ? .white : .black)
                                .cornerRadius(8)
                                .onTapGesture {
                                    if selectedInterests.contains(interest) {
                                        selectedInterests.remove(interest)
                                    } else {
                                        selectedInterests.insert(interest)
                                    }
                                }
                        }
                    }

                    Button("Finish") {
                        // Save profile info (optional storage)
                        authManager.isLoggedIn = true
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding()
            }
            .sheet(isPresented: $showImagePicker) {
            
            }
        }
    }
}
