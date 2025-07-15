//
//  SwipablePinCardsView.swift
//  Project Columbus
//
//  Created by Claude Code on 2024-07-15.
//

import SwiftUI

struct SwipablePinCardsView: View {
    let pins: [Pin]
    let onPinChanged: (Pin) -> Void
    @State private var currentIndex = 0
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Page indicator dots
            HStack {
                ForEach(0..<pins.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? .blue : .gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            print("🔵 [SwipablePinCards] Dot tapped: \(index)")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentIndex = index
                            }
                            // Call callback to center map on tapped pin
                            if index < pins.count {
                                print("🗺️ [SwipablePinCards] Centering map on pin: \(pins[index].locationName)")
                                onPinChanged(pins[index])
                            }
                        }
                }
            }
            .padding(.bottom, 8)
            
            // Swipable cards using TabView
            TabView(selection: $currentIndex) {
                ForEach(Array(pins.enumerated()), id: \.element.id) { index, pin in
                    PinCardView(pin: pin)
                        .tag(index)
                        .onAppear {
                            print("🎴 [SwipablePinCards] Card appeared for: \(pin.locationName) at index \(index)")
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentIndex) { oldValue, newValue in
                print("📱 [SwipablePinCards] Index changed from \(oldValue) to \(newValue)")
                if newValue < pins.count {
                    print("📍 [SwipablePinCards] Now showing: \(pins[newValue].locationName)")
                    print("🗺️ [SwipablePinCards] Auto-centering map on: \(pins[newValue].locationName)")
                    onPinChanged(pins[newValue])
                }
            }
        }
        .onAppear {
            print("🚀 [SwipablePinCards] View appeared with \(pins.count) pins")
            print("📋 [SwipablePinCards] Pin locations: \(pins.map { $0.locationName })")
            // Center map on first pin when view appears
            if !pins.isEmpty {
                print("🗺️ [SwipablePinCards] Initial centering map on: \(pins[0].locationName)")
                onPinChanged(pins[0])
            }
        }
        .onDisappear {
            print("👋 [SwipablePinCards] View disappeared")
        }
    }
}