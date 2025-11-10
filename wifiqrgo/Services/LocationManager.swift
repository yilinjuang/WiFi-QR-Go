import Foundation
import AppKit
@preconcurrency import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    // Callback for when permission is granted after being denied
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

    func requestLocationPermission() async -> Bool {
        switch authorizationStatus {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.authorizationContinuation = continuation

                // Request authorization (already on main thread via @MainActor)
                self.locationManager.requestWhenInUseAuthorization()

                // Request location to trigger the callback (macOS workaround)
                self.locationManager.requestLocation()

                // Add a timeout in case the callback never fires
                Task {
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
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

    func isAuthorized() -> Bool {
        return authorizationStatus == .authorizedAlways || authorizationStatus == .authorized
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    // CLLocationManagerDelegate methods
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let oldStatus = authorizationStatus
            authorizationStatus = manager.authorizationStatus

            // Resume the continuation if we were waiting for authorization
            if let continuation = authorizationContinuation {
                authorizationContinuation = nil
                let isAuthorized = authorizationStatus == .authorizedAlways || authorizationStatus == .authorized
                continuation.resume(returning: isAuthorized)
            }

            // Check if permission was just granted (changed from denied/notDetermined to authorized)
            let wasUnauthorized = oldStatus == .denied || oldStatus == .notDetermined || oldStatus == .restricted
            let isNowAuthorized = authorizationStatus == .authorized || authorizationStatus == .authorizedAlways

            if wasUnauthorized && isNowAuthorized {
                onPermissionGranted?()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location update received (only needed to trigger authorization callback on macOS)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore location errors, we only care about authorization
    }
}

