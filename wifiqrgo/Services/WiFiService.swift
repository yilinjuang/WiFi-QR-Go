import Foundation
import CoreWLAN
import AppKit
import CoreLocation

/// Errors that can occur during WiFi connection operations.
enum WiFiConnectionError: Error {
    case noInterface
    case connectionFailed(String)
    case networkNotFound
    case missingPassword
    case maxRetriesExceeded
    case locationPermissionDenied
    case userCancelled
}

/// Manages WiFi network scanning and connection operations using CoreWLAN.
class WiFiService {
    static let shared = WiFiService()

    private let wifiClient = CWWiFiClient.shared()
    private let maxRetries = 5
    private let initialBackoffDelay: TimeInterval = 0.5

    private init() {}

    /// Connects to a WiFi network using the provided credentials.
    /// - Parameter credentials: The WiFi network credentials from a QR code.
    /// - Throws: `WiFiConnectionError` if connection fails.
    func connect(to credentials: WiFiCredentials) async throws {
        guard let interface = wifiClient.interface() else {
            throw WiFiConnectionError.noInterface
        }

        // Verify location permission (required for WiFi SSID access on macOS 13+)
        try await ensureLocationPermission()

        // Validate credentials
        guard credentials.encryptionType == nil || credentials.encryptionType == "nopass" || credentials.password != nil else {
            throw WiFiConnectionError.missingPassword
        }

        // Try to connect with retries and exponential backoff
        var currentRetry = 0
        var lastError: Error?

        while currentRetry < maxRetries {
            do {
                // Attempt to scan and connect
                let network = try await scanForNetwork(interface: interface, ssid: credentials.ssid, retryAttempt: currentRetry)

                if let password = credentials.password {
                    try interface.associate(to: network, password: password)
                } else {
                    try interface.associate(to: network, password: nil)
                }

                // Connection successful
                return

            } catch let error {
                lastError = error
                currentRetry += 1

                // Only retry if this is a known retryable error
                if !isRetryableError(error) {
                    throw WiFiConnectionError.connectionFailed(error.localizedDescription)
                }

                if currentRetry < maxRetries {
                    // Calculate delay with exponential backoff
                    let delay = calculateBackoffDelay(retry: currentRetry)
                    // Wait before next retry
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // If we exhausted all retries, throw the last error or a generic error
        if let error = lastError {
            throw WiFiConnectionError.connectionFailed("Max retries exceeded. Last error: \(error.localizedDescription)")
        } else {
            throw WiFiConnectionError.maxRetriesExceeded
        }
    }

    // MARK: - Private Methods

    /// Ensures location permission is granted. Shows alert if denied.
    /// - Throws: `WiFiConnectionError.locationPermissionDenied` or `.userCancelled`
    private func ensureLocationPermission() async throws {
        let isAuthorized = await MainActor.run {
            LocationManager.shared.isAuthorized()
        }

        guard !isAuthorized else { return }

        let granted = await LocationManager.shared.requestLocationPermission()

        guard !granted else { return }

        // Show alert to user
        let userWantsToOpenSettings = await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Location Permission Required"
            alert.informativeText = "WiFi QR Go needs location access to scan and identify WiFi networks. This is a macOS requirement for accessing WiFi network names (SSIDs).\n\nPlease enable location services in System Settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                LocationManager.shared.openSystemSettings()
                return true
            }
            return false
        }

        throw userWantsToOpenSettings ? WiFiConnectionError.userCancelled : WiFiConnectionError.locationPermissionDenied
    }

    /// Scans for a specific network with retry logic.
    private func scanForNetwork(interface: CWInterface, ssid: String, retryAttempt: Int) async throws -> CWNetwork {
        guard let ssidData = ssid.data(using: .utf8) else {
            throw WiFiConnectionError.networkNotFound
        }

        var scanAttempt = 0
        let maxScanAttempts = 3

        while scanAttempt < maxScanAttempts {
            do {
                let networks = try interface.scanForNetworks(withSSID: ssidData)

                guard !networks.isEmpty else {
                    throw WiFiConnectionError.networkNotFound
                }

                // Pick the network with the strongest signal (highest RSSI)
                let bestNetwork = networks.sorted { $0.rssiValue > $1.rssiValue }.first!
                return bestNetwork

            } catch let error as NSError {
                scanAttempt += 1

                // Retry on EBUSY (error code 16) - "Resource busy"
                if error.code == 16 && scanAttempt < maxScanAttempts {
                    let scanDelay = 0.2 * Double(scanAttempt + retryAttempt)
                    try await Task.sleep(nanoseconds: UInt64(scanDelay * 1_000_000_000))
                } else {
                    throw error
                }
            }
        }

        throw WiFiConnectionError.networkNotFound
    }

    /// Calculates retry delay using exponential backoff with jitter.
    /// - Parameter retry: The current retry attempt number (1-based).
    /// - Returns: The delay in seconds before the next retry.
    private func calculateBackoffDelay(retry: Int) -> TimeInterval {
        let exponentialDelay = initialBackoffDelay * pow(2.0, Double(retry - 1))
        let jitter = Double.random(in: 0...0.3) * exponentialDelay
        return exponentialDelay + jitter
    }

    /// Determines if an error should be retried based on error code and domain.
    /// - Parameter error: The error to check.
    /// - Returns: `true` if the error is transient and should be retried.
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError

        let retryableCodes = [
            16,      // EBUSY - Resource busy
            -3900,   // Generic CoreWLAN error
            -3901,   // No memory
            -3902,   // Unknown error
            -3903,   // Not supported
            -3904,   // Invalid parameter
            -3905,   // No such property
            -3906,   // No such SSID
            -3913,   // Operation not permitted
            -3924,   // Interface powered off
        ]

        return retryableCodes.contains(nsError.code) ||
               nsError.domain == "com.apple.wifi.apple80211API.error" ||
               nsError.domain.contains("CoreWLAN")
    }

    /// Opens System Settings to the Wi-Fi network preferences panel.
    func openNetworkPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}