//
//  LocationFuzzer.swift
//  Project Columbus
//
//  Created by Assistant
//

import Foundation
import CoreLocation

struct LocationFuzzer {
    
    /// Fuzzes a coordinate by a given radius in meters.
    /// This function introduces a random offset to the coordinate to reduce its precision.
    ///
    /// - Parameters:
    ///   - coordinate: The original `CLLocationCoordinate2D` to fuzz.
    ///   - radius: The maximum radius of the random offset, in meters. If the radius is zero or less, the original coordinate is returned.
    /// - Returns: A new `CLLocationCoordinate2D` with a random offset, or the original coordinate if the radius is not positive.
    static func fuzz(coordinate: CLLocationCoordinate2D, by radius: Double) -> CLLocationCoordinate2D {
        // If no radius is provided, return the original coordinate
        guard radius > 0 else {
            return coordinate
        }
        
        // Earth's radius in meters
        let earthRadius: Double = 6378137.0
        
        // Convert radius from meters to radians
        let radiusInRadians = radius / earthRadius
        
        // Generate a random angle and a random distance (ensuring uniform distribution within the circle)
        let randomAngle = Double.random(in: 0...(2 * .pi))
        let randomRadius = radiusInRadians * sqrt(Double.random(in: 0...1))
        
        // Calculate the offset in radians
        let latOffset = randomRadius * cos(randomAngle)
        let lonOffset = randomRadius * sin(randomAngle)
        
        // Convert original coordinate to radians
        let originalLatRad = coordinate.latitude * .pi / 180.0
        let originalLonRad = coordinate.longitude * .pi / 180.0
        
        // Calculate the new coordinate in radians
        var newLatRad = originalLatRad + latOffset
        // Adjust longitude offset based on latitude
        var newLonRad = originalLonRad + lonOffset / cos(originalLatRad)
        
        // Convert back to degrees
        newLatRad = newLatRad * 180.0 / .pi
        newLonRad = newLonRad * 180.0 / .pi
        
        // Ensure the new coordinate is valid
        let newLatitude = min(max(newLatRad, -90.0), 90.0)
        let newLongitude = min(max(newLonRad, -180.0), 180.0)
        
        return CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
    }
} 