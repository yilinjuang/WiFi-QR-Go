import Foundation
import AppKit
@preconcurrency import CoreLocation

/// Manages location services authorization required for WiFi SSID access on macOS.
/// On macOS 13+, accessing WiFi network names requires location permission.
@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    /// Callback invoked when location permission is granted after being denied
    var onPermissionGranted: (() -> Void)?

    private override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorized Always"
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }

    /// Requests location permission from the user.
    /// - Returns: `true` if permission is granted, `false` otherwise.
    func requestLocationPermission() async -> Bool {
        switch authorizationStatus {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.authorizationContinuation = continuation

                self.locationManager.requestWhenInUseAuthorization()

                // Trigger authorization callback on macOS (workaround for delegate not firing)
                self.locationManager.requestLocation()

                // Timeout fallback if delegate callback doesn't fire
                Task {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                    if self.authorizationContinuation != nil {
                        self.authorizationContinuation = nil
                        let isAuthorized = self.locationManager.authorizationStatus == .authorizedAlways ||
                                         self.locationManager.authorizationStatus == .authorized
                        continuation.resume(returning: isAuthorized)
                    }
                }
            }
        case .denied, .restricted:
            return false
        case .authorizedAlways, .authorized:
            return true
        @unknown default:
            return false
        }
    }

    /// Checks if location services are currently authorized.
    /// - Returns: `true` if authorized, `false` otherwise.
    func isAuthorized() -> Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorized
    }

    /// Opens System Settings to the Location Services privacy panel.
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let oldStatus = authorizationStatus
            authorizationStatus = manager.authorizationStatus

            // Resume pending authorization request
            if let continuation = authorizationContinuation {
                authorizationContinuation = nil
                let isAuthorized = authorizationStatus == .authorizedAlways || authorizationStatus == .authorized
                continuation.resume(returning: isAuthorized)
            }

            // Notify if permission was just granted
            let wasUnauthorized = oldStatus == .denied || oldStatus == .notDetermined || oldStatus == .restricted
            let isNowAuthorized = authorizationStatus == .authorized || authorizationStatus == .authorizedAlways

            if wasUnauthorized && isNowAuthorized {
                onPermissionGranted?()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Required for requestLocation(), but we don't need the actual location data
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location errors are ignored; we only need authorization status
    }
}

