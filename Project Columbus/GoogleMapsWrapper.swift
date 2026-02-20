import SwiftUI
import MapKit

// Import GoogleMapsMocks for mock types when SDK not available

// Note: PinAnnotation is defined in Models.swift
// Note: Pin is defined in Models.swift

#if canImport(GoogleMaps)
import GoogleMaps
#endif

#if canImport(GoogleMaps)
// MARK: - Google Maps View Wrapper

/**
 * GoogleMapsView
 * 
 * A SwiftUI wrapper around GMSMapView that provides the same interface as MapKit's Map view.
 * This component maintains feature parity with the existing MapKit implementation while
 * using Google Maps as the underlying provider.
 */
struct GoogleMapsView: UIViewRepresentable {
    @Binding var cameraPosition: GMSCameraPosition
    @Binding var selectedAnnotation: UUID?
    
    let annotations: [PinAnnotation]
    let mapType: GMSMapViewType
    let showsUserLocation: Bool
    let onCameraChange: ((GMSCameraPosition) -> Void)?
    let onAnnotationTap: ((UUID) -> Void)?
    
    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView()
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = showsUserLocation
        mapView.mapType = mapType
        mapView.camera = cameraPosition
        
        // Match MapKit styling preferences
        mapView.settings.compassButton = false
        mapView.settings.myLocationButton = false
        mapView.settings.rotateGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.tiltGestures = true
        mapView.settings.zoomGestures = true
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update camera position
        if mapView.camera != cameraPosition {
            mapView.animate(to: cameraPosition)
        }
        
        // Update map type
        mapView.mapType = mapType
        mapView.isMyLocationEnabled = showsUserLocation
        
        // Update annotations
        mapView.clear()
        context.coordinator.annotations = annotations
        
        for annotation in annotations {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: annotation.latitude, longitude: annotation.longitude)
            marker.title = annotation.title
            marker.userData = annotation.id
            marker.map = mapView
            
            // Use custom marker view if provided
            if let customView = annotation.customView {
                // Convert SwiftUI view to UIImage for Google Maps compatibility
                let image = renderSwiftUIViewToImage(customView)
                marker.icon = image
            } else {
                // Default red pin to match MapKit
                marker.icon = GMSMarker.markerImage(with: .red)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Helper Functions
    
    /// Renders a SwiftUI view to a UIImage for use as a Google Maps marker icon
    private func renderSwiftUIViewToImage(_ view: AnyView) -> UIImage {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = UIColor.clear
        
        // Determine the size needed for the view
        let targetSize = CGSize(width: 60, height: 80) // Adjust size as needed
        hostingController.view.frame = CGRect(origin: .zero, size: targetSize)
        
        // Force layout
        hostingController.view.layoutIfNeeded()
        
        // Create the image
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { context in
            hostingController.view.layer.render(in: context.cgContext)
        }
        
        return image
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapsView
        var annotations: [PinAnnotation] = []
        
        init(_ parent: GoogleMapsView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            DispatchQueue.main.async {
                self.parent.cameraPosition = position
                self.parent.onCameraChange?(position)
            }
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let annotationId = marker.userData as? UUID {
                DispatchQueue.main.async {
                    self.parent.selectedAnnotation = annotationId
                    self.parent.onAnnotationTap?(annotationId)
                }
            }
            return true
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            // Handle map tap (deselect annotations)
            DispatchQueue.main.async {
                self.parent.selectedAnnotation = nil
            }
        }
    }
}

#endif

#if canImport(GoogleMaps)
// MARK: - MapKit to Google Maps Converter

/**
 * MapConverter
 * 
 * Utility class for converting between MapKit and Google Maps data structures.
 * Maintains coordinate and camera position compatibility.
 */
struct MapConverter {
    
    /// Convert MKCoordinateRegion to GMSCameraPosition
    static func gmsCamera(from mkRegion: MKCoordinateRegion) -> GMSCameraPosition {
        return GMSCameraPosition(
            latitude: mkRegion.center.latitude,
            longitude: mkRegion.center.longitude,
            zoom: zoomLevel(from: mkRegion.span)
        )
    }
    
    /// Convert GMSCameraPosition to MKCoordinateRegion
    static func mkRegion(from gmsCamera: GMSCameraPosition, span: MKCoordinateSpan? = nil) -> MKCoordinateRegion {
        let calculatedSpan = span ?? coordinateSpan(from: gmsCamera.zoom)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: gmsCamera.target.latitude, longitude: gmsCamera.target.longitude),
            span: calculatedSpan
        )
    }
    
    /// Convert map type string to Google Maps type
    static func mapType(from string: String) -> GMSMapViewType {
        switch string {
        case "Satellite":
            return .satellite
        case "Hybrid":
            return .hybrid
        default:
            return .normal
        }
    }
    
    /// Convert Google Maps type to string
    static func mapTypeString(from type: GMSMapViewType) -> String {
        switch type {
        case .satellite:
            return "Satellite"
        case .hybrid:
            return "Hybrid"
        default:
            return "Standard"
        }
    }
    
    // MARK: - Private Helpers
    
    /// Convert MKCoordinateSpan to Google Maps zoom level
    private static func zoomLevel(from span: MKCoordinateSpan) -> Float {
        let maxZoom: Float = 21.0
        let longitudeDelta = span.longitudeDelta
        
        if longitudeDelta <= 0 { return maxZoom }
        
        // Calculate zoom level based on longitude delta
        let zoomLevel = log2(360.0 / longitudeDelta)
        return min(maxZoom, max(0, Float(zoomLevel)))
    }
    
    /// Convert Google Maps zoom level to MKCoordinateSpan
    private static func coordinateSpan(from zoom: Float) -> MKCoordinateSpan {
        let longitudeDelta = 360.0 / pow(2.0, Double(zoom))
        let latitudeDelta = longitudeDelta * 0.75 // Approximate aspect ratio
        
        return MKCoordinateSpan(
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
    }
}

// MARK: - SwiftUI Convenience Extensions

extension View {
    /// Apply Google Maps styling that matches MapKit appearance
    func googleMapsStyle() -> some View {
        self
            .background(Color.clear)
            .cornerRadius(12)
    }
}

// MARK: - Default Camera Positions

extension GMSCameraPosition {
    /// Default San Francisco camera position matching MapKit default
    static let defaultSanFrancisco = GMSCameraPosition(
        latitude: 37.7749,
        longitude: -122.4194,
        zoom: 13.0
    )
    
    /// Create camera position from coordinate with standard zoom
    static func standard(coordinate: CLLocationCoordinate2D, zoom: Float = 15.0) -> GMSCameraPosition {
        return GMSCameraPosition(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            zoom: zoom
        )
    }
}
#else
// MARK: - Fallback when Google Maps SDK is not available

import SwiftUI

struct GoogleMapsView: View {
    @Binding var cameraPosition: GMSCameraPosition
    @Binding var selectedAnnotation: UUID?
    
    let annotations: [PinAnnotation]
    let mapType: GMSMapViewType
    let showsUserLocation: Bool
    let onCameraChange: ((GMSCameraPosition) -> Void)?
    let onAnnotationTap: ((UUID) -> Void)?
    
    var body: some View {
        Text("Google Maps SDK not available")
            .foregroundColor(.red)
            .padding()
    }
}

struct GMSCameraPosition {
    let target: CLLocationCoordinate2D
    let zoom: Float
    
    init(latitude: Double, longitude: Double, zoom: Float) {
        self.target = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.zoom = zoom
    }
    
    static let defaultSanFrancisco = GMSCameraPosition(
        latitude: 37.7749,
        longitude: -122.4194,
        zoom: 13.0
    )
    
    static func standard(coordinate: CLLocationCoordinate2D, zoom: Float = 15.0) -> GMSCameraPosition {
        return GMSCameraPosition(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            zoom: zoom
        )
    }
}

enum GMSMapViewType {
    case normal, satellite, hybrid
}
#endif 