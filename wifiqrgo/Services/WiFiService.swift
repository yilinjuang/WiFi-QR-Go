import Foundation
import CoreWLAN
import AppKit
import CoreLocation

enum WiFiConnectionError: Error {
    case noInterface
    case connectionFailed(String)
    case networkNotFound
    case missingPassword
    case maxRetriesExceeded
    case locationPermissionDenied
    case userCancelled // User cancelled operation (e.g., going to settings)
}

class WiFiService {
    static let shared = WiFiService()

    private let wifiClient = CWWiFiClient.shared()
    private let maxRetries = 5
    private let initialBackoffDelay: TimeInterval = 0.5 // Initial delay in seconds

    private init() {}

    func connect(to credentials: WiFiCredentials) async throws {
        guard let interface = wifiClient.interface() else {
            throw WiFiConnectionError.noInterface
        }

        // Check location authorization (required for WiFi SSID access on macOS)
        let isAuthorized = await MainActor.run {
            LocationManager.shared.isAuthorized()
        }

        if !isAuthorized {
            let granted = await LocationManager.shared.requestLocationPermission()

            if !granted {
                // Show alert to user on main thread
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

                // If user chose to open settings, throw userCancelled (don't show error)
                // If user clicked cancel, throw locationPermissionDenied (show error)
                throw userWantsToOpenSettings ? WiFiConnectionError.userCancelled : WiFiConnectionError.locationPermissionDenied
            }
        }

        // Check if password is required but not provided
        if credentials.encryptionType != nil && credentials.encryptionType != "nopass" && credentials.password == nil {
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

    // Scans for a specific network with retries
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

                // Error code 16 is EBUSY - "Resource busy"
                if error.code == 16 && scanAttempt < maxScanAttempts {
                    let scanDelay = 0.2 * Double(scanAttempt + retryAttempt)
                    try await Task.sleep(nanoseconds: UInt64(scanDelay * 1_000_000_000))
                } else if scanAttempt >= maxScanAttempts {
                    throw error
                } else {
                    throw error
                }
            }
        }

        throw WiFiConnectionError.networkNotFound
    }

    // Calculate delay with exponential backoff
    private func calculateBackoffDelay(retry: Int) -> TimeInterval {
        // Exponential backoff with some randomness to avoid thundering herd
        let exponentialDelay = initialBackoffDelay * pow(2.0, Double(retry - 1))
        let jitter = Double.random(in: 0...0.3) * exponentialDelay
        return exponentialDelay + jitter
    }

    // Determine if an error is retryable
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Error codes that indicate temporary issues we should retry
        let retryableCodes = [
            16,      // EBUSY - Resource busy
            -3900,   // Generic error
            -3901,   // No memory
            -3902,   // Unknown error
            -3903,   // Not supported
            -3904,   // Invalid parameter
            -3905,   // No such property
            -3906,   // No such SSID
            -3913,   // Op not permitted
            -3924,   // Power off
        ]

        return retryableCodes.contains(nsError.code) ||
               nsError.domain == "com.apple.wifi.apple80211API.error" ||
               nsError.domain.contains("CoreWLAN")
    }

    func openNetworkPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi")!
        NSWorkspace.shared.open(url)
    }
}