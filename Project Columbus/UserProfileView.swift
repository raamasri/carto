//
//  UserProfileView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import SwiftUI
import MapKit

struct UserProfileView: View {
    let currentUserID = UUID()
    
    @State var profileUser = User(
        id: UUID(),
        username: "mojojojo",
        isPrivate: false,
        followers: Array(repeating: UUID(), count: 5),
        following: Array(repeating: UUID(), count: 10),
        followRequests: [],
        collections: [
            PinCollection(name: "San Francisco", pins: [
                Pin(locationName: "Zuni Café", city: "San Francisco", date: "Mar 26", latitude: 37.7730, longitude: -122.4210, reaction: .lovedIt),
                Pin(locationName: "Tartine Bakery", city: "San Francisco", date: "Mar 25", latitude: 37.7614, longitude: -122.4241, reaction: .lovedIt),
                Pin(locationName: "House of Prime Rib", city: "San Francisco", date: "Mar 24", latitude: 37.7930, longitude: -122.4228, reaction: .wantToGo),
                Pin(locationName: "La Taqueria", city: "San Francisco", date: "Mar 23", latitude: 37.7502, longitude: -122.4185, reaction: .wantToGo),
                Pin(locationName: "Swan Oyster Depot", city: "San Francisco", date: "Mar 22", latitude: 37.7913, longitude: -122.4212, reaction: .lovedIt)
            ]),
            PinCollection(name: "Bday", pins: []),
            PinCollection(name: "Car Tour", pins: []),
            PinCollection(name: "Europe 25", pins: []),
            PinCollection(name: "Psychos", pins: []),
            PinCollection(name: "Pizza", pins: [])
        ],
        favoriteSpots: [],
        activityFeed: []
    )
    
    @State private var bio = "✨ Travel lover. Coffee first. Exploring the world one pin at a time! 🌍"
    @State private var selectedSection = "Just Added"
    let sections = ["Just Added", "Loved", "Want to Go", "Recommendations"]
    
    @State var recentPins: [Pin] = [
        Pin(locationName: "Golden Gate Park", city: "San Francisco", date: "Mar 10", latitude: 37.7694, longitude: -122.4862, reaction: .lovedIt),
        Pin(locationName: "Central Park", city: "New York", date: "Feb 22", latitude: 40.7851, longitude: -73.9683, reaction: .wantToGo),
        Pin(locationName: "Eiffel Tower", city: "Paris", date: "Jan 18", latitude: 48.8584, longitude: 2.2945, reaction: .lovedIt)
    ]
    
    @State private var selectedFilter: Reaction? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("@\(profileUser.username)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Profile Header
                    ZStack(alignment: .topTrailing) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(profileUser.username)")
                                    .font(.headline)
                                
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                
                                Text("\(profileUser.followers.count) followers • \(profileUser.following.count) following")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            Button(action: {}) {
                                Text("Edit Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            Button(action: {}) {
                                Text("Share profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Map Section
                        Map(
                            coordinateRegion: $region,
                            annotationItems: recentPins
                        ) { pin in
                            MapAnnotation(
                                coordinate: CLLocationCoordinate2D(
                                    latitude: pin.latitude,
                                    longitude: pin.longitude
                                )
                            ) {
                                Image(systemName: "mappin.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)
                                    .shadow(radius: 3)
                            }
                        }
                        .frame(height: 300)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .padding(.top, 12)
                    .padding(.vertical)
                    .padding(.bottom, 8)
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.top, 12)
    }
}
