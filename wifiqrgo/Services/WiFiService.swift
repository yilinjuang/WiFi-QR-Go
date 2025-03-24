import Foundation
import CoreWLAN
import AppKit

enum WiFiConnectionError: Error {
    case noInterface
    case connectionFailed(String)
    case networkNotFound
    case missingPassword
    case maxRetriesExceeded
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
                    // Connect to network with password
                    try interface.associate(to: network, password: password)
                } else {
                    // Connect to open network
                    try interface.associate(to: network, password: nil)
                }

                // Connection successful
                return

            } catch let error {
                lastError = error
                currentRetry += 1

                // Only retry if this is a known retryable error
                if !isRetryableError(error) {
                    // If not a retryable error, rethrow immediately
                    throw WiFiConnectionError.connectionFailed(error.localizedDescription)
                }

                if currentRetry < maxRetries {
                    // Calculate delay with exponential backoff
                    let delay = calculateBackoffDelay(retry: currentRetry)
                    print("WiFi connection attempt \(currentRetry) failed, retrying in \(delay) seconds...")

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
        let maxScanAttempts = 3 // Maximum attempts for scanning specifically

        while scanAttempt < maxScanAttempts {
            do {
                // Scan for the specific network
                let networks = try interface.scanForNetworks(withSSID: ssidData)

                // Check if the network was found
                guard !networks.isEmpty else {
                    throw WiFiConnectionError.networkNotFound
                }

                // If multiple networks with the same SSID were found, pick the one with the strongest signal
                let bestNetwork = networks.sorted { network1, network2 in
                    // Higher RSSI value (less negative) means stronger signal
                    return network1.rssiValue > network2.rssiValue
                }.first!

                return bestNetwork

            } catch let error as NSError {
                scanAttempt += 1

                // Error code 16 is EBUSY - "Resource busy"
                if error.code == 16 && scanAttempt < maxScanAttempts {
                    // Add a small delay between scan attempts, increasing with each retry
                    let scanDelay = 0.2 * Double(scanAttempt + retryAttempt)
                    print("WiFi scan attempt \(scanAttempt) failed with error code \(error.code), retrying in \(scanDelay) seconds...")
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

        // Error code 16 = Resource busy
        // Error code -3900 to -3910 = Various network errors that may be temporary
        let retryableCodes = [16, -3900, -3901, -3902, -3903, -3904, -3905]

        return retryableCodes.contains(nsError.code) ||
               nsError.domain == "com.apple.wifi.apple80211API.error"
    }

    func openNetworkPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi")!
        NSWorkspace.shared.open(url)
    }
}