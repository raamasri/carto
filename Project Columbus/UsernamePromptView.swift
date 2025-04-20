//
//  UsernamePromptView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/19/25.
//

import SwiftUI

struct UsernamePromptView: View {
    @State private var username: String = ""
    var onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a Username")
                .font(.title2)
                .bold()

            TextField("Enter a username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button(action: {
                guard !username.isEmpty else { return }
                onSubmit(username)
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
