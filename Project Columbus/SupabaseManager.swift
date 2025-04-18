//
//  SupabaseManager.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/17/25.
//

import Supabase
import Foundation

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let supabaseUrl = URL(string: "https://rthgzxorsccgeztwaxnt.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0aGd6eG9yc2NjZ2V6dHdheG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ4NTYyNTMsImV4cCI6MjA2MDQzMjI1M30.mbXmJTsBIMHdlL_lcSAX0Zd87YH-_jDkWb8H6W1wW6I"

        self.client = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey
        )
    }
    
    func getCurrentUsername() async -> String? {
        do {
            let session = try await client.auth.session
            let userId = session.user.id

            let response = try await client
                .database
                .from("profiles")
                .select("username")
                .eq("id", value: userId)
                .single()
                .execute()

            if let data = response.value as? [String: Any],
               let username = data["username"] as? String {
                return username
            }
        } catch {
            print("Error fetching username: \(error)")
        }

        return nil
    }
}
