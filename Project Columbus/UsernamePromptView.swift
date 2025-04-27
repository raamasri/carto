//
//  UsernamePromptView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/19/25.
//

import SwiftUI
import Foundation
// import Supabase if needed

struct UsernamePromptView: View {
    @State private var username: String = ""
    @State private var isChecking = false
    @State private var errorMessage: String? = nil
    var onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a Username")
                .font(.title2)
                .bold()

            UsernameTextField(text: $username)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                guard !username.isEmpty else { return }
                isChecking = true
                errorMessage = nil
                Task {
                    let available = await SupabaseManager.shared.isUsernameAvailable(username: username)
                    isChecking = false
                    if available {
                        onSubmit(username)
                    } else {
                        errorMessage = "Username is already taken."
                    }
                }
            }) {
                if isChecking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(username.isEmpty || isChecking)
        }
        .padding()
    }
}

struct UsernameTextField: View {
    @Binding var text: String
    var body: some View {
        Group {
            if #available(iOS 15.0, *) {
                TextField("Enter a username", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocorrectionDisabled(true)
            } else {
                TextField("Enter a username", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
    }
}
