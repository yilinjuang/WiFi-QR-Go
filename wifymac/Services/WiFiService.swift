import Foundation
import CoreWLAN
import AppKit

enum WiFiConnectionError: Error {
    case noInterface
    case connectionFailed(String)
    case unsupportedNetwork
    case missingPassword
    case unknown
}

class WiFiService {
    static let shared = WiFiService()

    private let wifiClient = CWWiFiClient.shared()

    private init() {}

    func connect(to credentials: WiFiCredentials) async throws {
        guard let interface = wifiClient.interface() else {
            throw WiFiConnectionError.noInterface
        }

        // Check if password is required but not provided
        if credentials.encryptionType != nil && credentials.encryptionType != "nopass" && credentials.password == nil {
            throw WiFiConnectionError.missingPassword
        }

        do {
            // Scan for available networks
            let networks = try interface.scanForNetworks(withSSID: nil)

            // Find the network with matching SSID
            guard let network = networks.first(where: { $0.ssid == credentials.ssid }) else {
                throw WiFiConnectionError.unsupportedNetwork
            }

            if let password = credentials.password {
                // Connect to network with password
                try interface.associate(to: network, password: password)
            } else {
                // Connect to open network
                try interface.associate(to: network, password: nil)
            }
            return
        } catch {
            throw WiFiConnectionError.connectionFailed(error.localizedDescription)
        }
    }

    func openNetworkPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi")!
        NSWorkspace.shared.open(url)
    }
}