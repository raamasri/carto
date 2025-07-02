//
//  DistanceFormatter.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import Foundation
import CoreLocation

struct DistanceFormatter {
    
    /// Formats distance in meters to a user-friendly string based on user preferences
    /// - Parameter distanceInMeters: Distance in meters
    /// - Returns: Formatted distance string (e.g., "1.2 mi" or "2.0 km")
    static func formatDistance(_ distanceInMeters: Double) -> String {
        let useImperialUnits = UserDefaults.standard.bool(forKey: "useImperialUnits")
        
        if useImperialUnits {
            // Convert to miles
            let miles = distanceInMeters * 0.000621371
            if miles < 0.1 {
                // Show in feet for very short distances
                let feet = distanceInMeters * 3.28084
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.1f mi", miles)
            }
        } else {
            // Convert to kilometers
            let kilometers = distanceInMeters / 1000
            if kilometers < 0.1 {
                // Show in meters for very short distances
                return String(format: "%.0f m", distanceInMeters)
            } else {
                return String(format: "%.1f km", kilometers)
            }
        }
    }
    
    /// Formats distance with a "Distance: " prefix
    /// - Parameter distanceInMeters: Distance in meters
    /// - Returns: Formatted distance string with prefix (e.g., "Distance: 1.2 mi")
    static func formatDistanceWithLabel(_ distanceInMeters: Double) -> String {
        return "Distance: \(formatDistance(distanceInMeters))"
    }
    
    /// Converts distance from kilometers to the user's preferred unit
    /// - Parameter kilometers: Distance in kilometers
    /// - Returns: Formatted distance string
    static func formatDistanceFromKilometers(_ kilometers: Double) -> String {
        let meters = kilometers * 1000
        return formatDistance(meters)
    }
} 