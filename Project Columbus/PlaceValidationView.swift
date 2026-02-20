import SwiftUI
import CoreLocation

/**
 * PlaceValidationView
 * 
 * UI component that displays place validation status and allows users to understand
 * the cross-validation results between Apple Maps and Google Maps.
 */
struct PlaceValidationView: View {
    let validatedPlace: PlaceValidationService.ValidatedPlace
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Place Validation")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Verifying location across map services")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Place Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(validatedPlace.displayName)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(validatedPlace.displayAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    Spacer()
                }
                
                // Coordinates
                Text("📍 \(formatCoordinate(validatedPlace.preferredCoordinate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 32)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Validation Status
            ValidationStatusCard(validatedPlace: validatedPlace)
            
            // Service Availability
            ServiceAvailabilityView(validatedPlace: validatedPlace)
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                
                Button(validatedPlace.canBeAdded ? "Add Place" : "Cannot Add") {
                    if validatedPlace.canBeAdded {
                        onConfirm()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validatedPlace.canBeAdded)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - Validation Status Card

struct ValidationStatusCard: View {
    let validatedPlace: PlaceValidationService.ValidatedPlace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: confidenceIcon)
                    .foregroundColor(confidenceColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Validation Status")
                        .font(.headline)
                    
                    Text(validatedPlace.confidence.displayText)
                        .font(.subheadline)
                        .foregroundColor(confidenceColor)
                }
                
                Spacer()
                
                if let distance = validatedPlace.coordinateDistance {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(String(format: "%.0f", distance))m")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Text(validatedPlace.validationMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 32)
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(confidenceColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var confidenceIcon: String {
        switch validatedPlace.confidence {
        case .high:
            return "checkmark.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .low:
            return "questionmark.circle.fill"
        case .unknown:
            return "xmark.circle.fill"
        }
    }
    
    private var confidenceColor: Color {
        switch validatedPlace.confidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .yellow
        case .unknown:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        switch validatedPlace.confidence {
        case .high:
            return .green.opacity(0.1)
        case .medium:
            return .orange.opacity(0.1)
        case .low:
            return .yellow.opacity(0.1)
        case .unknown:
            return .red.opacity(0.1)
        }
    }
}

// MARK: - Service Availability View

struct ServiceAvailabilityView: View {
    let validatedPlace: PlaceValidationService.ValidatedPlace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Service Availability")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 20) {
                ServiceStatusItem(
                    serviceName: "Apple Maps",
                    isAvailable: validatedPlace.applePlace != nil,
                    icon: "map"
                )
                
                ServiceStatusItem(
                    serviceName: "Google Maps",
                    isAvailable: validatedPlace.googlePlace != nil,
                    icon: "globe"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ServiceStatusItem: View {
    let serviceName: String
    let isAvailable: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isAvailable ? .blue : .gray)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(serviceName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isAvailable ? .green : .red)
                        .font(.caption2)
                    
                    Text(isAvailable ? "Found" : "Not found")
                        .font(.caption2)
                        .foregroundColor(isAvailable ? .green : .red)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Loading View for Validation

struct PlaceValidationLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Validating Place")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Checking across map services...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "map")
                            .foregroundColor(.blue)
                        Text("Searching Apple Maps...")
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Searching Google Maps...")
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Cross-validating results...")
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

// MARK: - Preview

#if DEBUG
struct PlaceValidationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // High confidence example
            PlaceValidationView(
                validatedPlace: PlaceValidationService.ValidatedPlace(
                    applePlace: nil, // Would be actual MKMapItem
                    googlePlace: nil, // Would be actual GMSPlace
                    isValidated: true,
                    preferredCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    confidence: .high,
                    validationMessage: "Found in both services with matching coordinates",
                    coordinateDistance: 15.5
                ),
                onConfirm: {},
                onCancel: {}
            )
            .previewDisplayName("High Confidence")
            
            // Loading view
            PlaceValidationLoadingView()
                .previewDisplayName("Loading")
        }
        .padding()
        .background(Color(.systemGray5))
    }
}
#endif