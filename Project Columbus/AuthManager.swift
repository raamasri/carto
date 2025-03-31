//
//  AuthManager.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/17/25.
//


import Foundation

class AuthManager: ObservableObject {
    @Published var isLoggedIn = false

    func logIn(username: String, password: String) {
        if !username.isEmpty && !password.isEmpty {
            isLoggedIn = true
        }
    }

    func logOut() {
        isLoggedIn = false
    }
}