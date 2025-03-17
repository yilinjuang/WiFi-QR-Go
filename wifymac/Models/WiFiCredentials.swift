import Foundation

struct WiFiCredentials {
    let ssid: String
    let password: String?
    let encryptionType: String?

    var isValid: Bool {
        !ssid.isEmpty
    }

    // Parse Wi-Fi credentials from QR code content
    static func parse(from qrCodeContent: String) -> WiFiCredentials? {
        // QR code format for Wi-Fi is typically: WIFI:S:<SSID>;T:<Authentication Type>;P:<Password>;;
        guard qrCodeContent.hasPrefix("WIFI:") else { return nil }

        var ssid = ""
        var password: String? = nil
        var encryptionType: String? = nil

        // Extract SSID
        if let ssidRange = qrCodeContent.range(of: "S:"),
           let endRange = qrCodeContent[ssidRange.upperBound...].firstIndex(of: ";") {
            ssid = String(qrCodeContent[ssidRange.upperBound..<endRange])
            // Handle escaped characters
            ssid = ssid.replacingOccurrences(of: "\\;", with: ";")
                       .replacingOccurrences(of: "\\:", with: ":")
                       .replacingOccurrences(of: "\\\\", with: "\\")
        }

        // Extract password
        if let pwdRange = qrCodeContent.range(of: "P:"),
           let endRange = qrCodeContent[pwdRange.upperBound...].firstIndex(of: ";") {
            password = String(qrCodeContent[pwdRange.upperBound..<endRange])
            // Handle escaped characters
            password = password?.replacingOccurrences(of: "\\;", with: ";")
                              .replacingOccurrences(of: "\\:", with: ":")
                              .replacingOccurrences(of: "\\\\", with: "\\")
        }

        // Extract encryption type
        if let typeRange = qrCodeContent.range(of: "T:"),
           let endRange = qrCodeContent[typeRange.upperBound...].firstIndex(of: ";") {
            encryptionType = String(qrCodeContent[typeRange.upperBound..<endRange])
        }

        return WiFiCredentials(ssid: ssid, password: password, encryptionType: encryptionType)
    }
}