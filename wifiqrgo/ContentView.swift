//
//  ContentView.swift
//  WiFiQRGo
//
//  Created by Yi-Lin Juang on 2025/3/17.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @EnvironmentObject private var viewModel: ContentViewModel
    @State private var isConnecting = false
    @State private var connectionError: Error?
    @State private var showingConnectionError = false
    @State private var activeToast: ToastMessage?
    @State private var pendingConnectionCredentials: WiFiCredentials?

    var body: some View {
        VStack {
            if cameraManager.isAuthorized {
                ZStack {
                    // Camera preview
                    CameraPreviewView(previewLayer: cameraManager.getPreviewLayer())
                        .frame(minWidth: 700, minHeight: 500)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray, lineWidth: 1)
                        )

                    // QR code capture overlay with toast functionality
                    QRCodeCaptureOverlay(toastMessage: activeToast)
                }
                .padding()
            } else {
                VStack(spacing: 30) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)

                    Text("Camera access is required")
                        .font(.title)

                    Text("Please allow camera access in System Settings")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(50)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Set up the callback for WiFi QR code detection when the view appears
            cameraManager.onWiFiQRCodeDetected = { [weak viewModel] credentials in
                viewModel?.wifiCredentials = credentials
                viewModel?.showingCredentialsAlert = true
            }

            // Set up location permission granted callback
            Task { @MainActor in
                LocationManager.shared.onPermissionGranted = {
                    // If we have pending credentials, auto-retry the connection
                    if let credentials = self.pendingConnectionCredentials {
                        self.showToast(.info(message: "Location permission granted! Retrying connection...", icon: "location.fill"))

                        // Clear pending credentials and retry
                        self.pendingConnectionCredentials = nil

                        // Wait a brief moment for the toast to show
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            await self.performConnection(to: credentials)
                        }
                    }
                }
            }
        }
        .alert("Connect to \(viewModel.wifiCredentials?.ssid ?? "Wi-Fi")?", isPresented: $viewModel.showingCredentialsAlert) {
            Button("Connect", role: .none) {
                connectToWiFi()
            }
            Button("Copy Password", role: .none) {
                if let password = viewModel.wifiCredentials?.password {
                    ClipboardHelper.copyToClipboard(password)
                    showToast(.info(message: "Password copied to clipboard", icon: "doc.on.clipboard"))
                }
            }
            .disabled(viewModel.wifiCredentials?.password == nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            if let credentials = viewModel.wifiCredentials {
                Text(createNetworkDetailsMessage(credentials))
            } else {
                Text("No network information available")
            }
        }
        .alert("Connection Error", isPresented: $showingConnectionError) {
            Button("Copy Password", role: .none) {
                if let password = viewModel.wifiCredentials?.password {
                    ClipboardHelper.copyToClipboard(password)
                    showToast(.info(message: "Password copied to clipboard", icon: "doc.on.clipboard"))
                }
            }
            .disabled(viewModel.wifiCredentials?.password == nil)
            Button("Try Again", role: .none) {
                connectToWiFi()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let error = connectionError {
                Text("Failed to connect: \(error.localizedDescription)")
            } else {
                Text("An unknown error occurred")
            }
        }
    }

    private func showToast(_ toast: ToastMessage, duration: Double? = 3.0) {
        withAnimation {
            activeToast = toast
        }

        // Only auto-dismiss if a duration is provided
        if let duration = duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation {
                    if self.activeToast?.message == toast.message {
                        self.activeToast = nil
                    }
                }
            }
        }
    }

    private func createNetworkDetailsMessage(_ credentials: WiFiCredentials) -> String {
        var message = "SSID: \(credentials.ssid)"

        if let password = credentials.password, !password.isEmpty {
            message += "\nPassword: \(password)"
        } else if credentials.encryptionType == "nopass" {
            message += "\nPassword: None (Open Network)"
        }

        if let encType = credentials.encryptionType {
            message += "\nSecurity: \(encType)"
        } else {
            message += "\nSecurity: Unknown"
        }

        return message
    }

    private func connectToWiFi() {
        guard let credentials = viewModel.wifiCredentials else { return }

        Task {
            await performConnection(to: credentials)
        }
    }

    private func performConnection(to credentials: WiFiCredentials) async {
        await MainActor.run {
            isConnecting = true
            // Show connecting toast with ProgressView and make it persist
            showToast(ToastMessage.connecting(message: "Connecting to \(credentials.ssid)"), duration: nil)
        }

        do {
            try await WiFiService.shared.connect(to: credentials)
            await MainActor.run {
                isConnecting = false
                pendingConnectionCredentials = nil // Clear any pending credentials on success
                // Replace the connecting toast with success toast
                showToast(.success(message: "Successfully connected to \(credentials.ssid)", icon: "wifi"))
            }
        } catch {
            await MainActor.run {
                isConnecting = false
                // Clear the connecting toast
                withAnimation {
                    activeToast = nil
                }

                // Check if user cancelled (e.g., went to open System Settings)
                // In that case, don't show the error dialog
                if let wifiError = error as? WiFiConnectionError,
                   case .userCancelled = wifiError {
                    // User is taking action to fix the issue, save credentials for auto-retry
                    pendingConnectionCredentials = credentials
                    showToast(.info(message: "Waiting for location permission...", icon: "hourglass"), duration: nil)
                    return
                }

                // Clear pending credentials on other errors
                pendingConnectionCredentials = nil

                // Show error for all other cases
                connectionError = error
                showingConnectionError = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContentViewModel())
}
