import Foundation
import Network
import CryptoKit

/**
 * CertificatePinningManager
 * 
 * Manages SSL certificate pinning for enhanced network security.
 * 
 * ⚠️ STATUS: CONFIGURED BUT PINS NOT SET
 * 
 * This manager is set up and ready to use, but certificate pins are intentionally 
 * left empty for development flexibility. The validation logic (line 56-59) allows
 * connections when pins are empty, printing a warning to console.
 * 
 * SECURITY CONSIDERATION:
 * - Development: Empty pins allow connections (current state)
 * - Production: Should populate pins and set validateCertificate to return false when empty
 * 
 * HOW TO ADD CERTIFICATE PINS:
 * 
 * 1. Get your server's certificate pin:
 * ```bash
 * openssl s_client -servername your-project.supabase.co -connect your-project.supabase.co:443 \
 *   | openssl x509 -pubkey -noout \
 *   | openssl rsa -pubin -outform der \
 *   | shasum -a 256 \
 *   | awk '{print $1}'
 * ```
 * 
 * 2. Add the hash to the appropriate array below
 * 
 * 3. For production, change line 58 from `return true` to `return false`
 * 
 * REFERENCES:
 * - OWASP Certificate Pinning Guide: https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning
 * - Apple's App Transport Security: https://developer.apple.com/documentation/security/preventing_insecure_network_connections
 */
class CertificatePinningManager: NSObject {
    static let shared = CertificatePinningManager()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Certificate Pins
    
    /// Known certificate pins for trusted domains
    /// ⚠️ Currently empty - connections will be allowed but logged (see documentation above)
    private let certificatePins: [String: Set<String>] = [
        // Supabase API endpoints
        // Example: "your-project.supabase.co": ["sha256_hash_of_public_key"]
        "supabase.co": [
            // TODO: Add your Supabase project's certificate pins here
        ],
        "supabase.com": [
            // TODO: Add Supabase main domain pins if needed
        ],
        // Add other domains you want to pin
        "api.apple.com": [
            // TODO: Add Apple API pins for Apple Sign In if needed
        ]
    ]
    
    // MARK: - URLSession Configuration
    
    /// Create a URLSession with certificate pinning
    func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Certificate Validation
    
    /// Validate certificate against known pins
    private func validateCertificate(_ trust: SecTrust, for host: String) -> Bool {
        // Get certificate chain
        guard let certificateChain = getCertificateChain(from: trust) else {
            print("⚠️ [CertPinning] Failed to get certificate chain for \(host)")
            return false
        }
        
        // Check if we have pins for this host
        let hostPins = certificatePins[host] ?? []
        
        // If no pins configured, allow connection (for development)
        if hostPins.isEmpty {
            print("⚠️ [CertPinning] No certificate pins configured for \(host)")
            return true // Allow for now, but should be false in production
        }
        
        // Validate each certificate in the chain
        for certificate in certificateChain {
            let publicKeyPin = getPublicKeyPin(from: certificate)
            
            if hostPins.contains(publicKeyPin) {
                print("✅ [CertPinning] Certificate validated for \(host)")
                return true
            }
        }
        
        print("❌ [CertPinning] Certificate validation failed for \(host)")
        return false
    }
    
    /// Extract certificate chain from SecTrust
    private func getCertificateChain(from trust: SecTrust) -> [SecCertificate]? {
        let certificateCount = SecTrustGetCertificateCount(trust)
        var certificates: [SecCertificate] = []
        
        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(trust, i) {
                certificates.append(certificate)
            }
        }
        
        return certificates.isEmpty ? nil : certificates
    }
    
    /// Generate public key pin from certificate
    private func getPublicKeyPin(from certificate: SecCertificate) -> String {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            return ""
        }
        
        let hash = SHA256.hash(data: publicKeyData as Data)
        return Data(hash).base64EncodedString()
    }
    
    // MARK: - Network Monitoring
    
    /// Monitor network path for security
    func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("🌐 [Network] Connection available")
                self?.logNetworkInterface(path)
            } else {
                print("⚠️ [Network] Connection unavailable")
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    /// Log network interface information
    private func logNetworkInterface(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            print("📶 [Network] Using WiFi")
        } else if path.usesInterfaceType(.cellular) {
            print("📱 [Network] Using Cellular")
        } else if path.usesInterfaceType(.wiredEthernet) {
            print("🔌 [Network] Using Wired Ethernet")
        }
        
        if path.isExpensive {
            print("💰 [Network] Connection is expensive")
        }
        
        if path.isConstrained {
            print("🚫 [Network] Connection is constrained")
        }
    }
}

// MARK: - URLSessionDelegate

extension CertificatePinningManager: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Get the server trust and host
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let host = URL(string: challenge.protectionSpace.host)?.host else {
            print("❌ [CertPinning] Invalid server trust or host")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate the certificate
        if validateCertificate(serverTrust, for: host) {
            // Certificate is valid, create credential
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Certificate validation failed
            print("❌ [CertPinning] Certificate validation failed for \(host)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Helper Extensions

extension CertificatePinningManager {
    /// Add certificate pin for a domain
    func addCertificatePin(_ pin: String, for domain: String) {
        // This would be used to dynamically add pins
        // For production, pins should be hardcoded
        print("📌 [CertPinning] Adding pin for \(domain): \(pin)")
    }
    
    /// Remove certificate pin for a domain
    func removeCertificatePin(for domain: String) {
        print("🗑️ [CertPinning] Removing pins for \(domain)")
    }
    
    /// Get current certificate pins for debugging
    func getCurrentPins() -> [String: Set<String>] {
        return certificatePins
    }
}

// MARK: - Network Security Utilities

extension CertificatePinningManager {
    /// Check if connection is secure
    func isConnectionSecure(for url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https"
    }
    
    /// Validate URL security
    func validateURLSecurity(_ url: URL) throws {
        guard isConnectionSecure(for: url) else {
            throw NetworkSecurityError.insecureConnection("URL must use HTTPS: \(url)")
        }
        
        guard let host = url.host, !host.isEmpty else {
            throw NetworkSecurityError.invalidHost("Invalid or empty host: \(url)")
        }
    }
}

// MARK: - Error Types

enum NetworkSecurityError: LocalizedError {
    case insecureConnection(String)
    case invalidHost(String)
    case certificateValidationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .insecureConnection(let message):
            return "Insecure connection: \(message)"
        case .invalidHost(let message):
            return "Invalid host: \(message)"
        case .certificateValidationFailed(let message):
            return "Certificate validation failed: \(message)"
        }
    }
} 