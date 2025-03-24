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

        isConnecting = true
        // Show connecting toast with ProgressView and make it persist
        showToast(ToastMessage.connecting(message: "Connecting to \(credentials.ssid)"), duration: nil)

        Task {
            do {
                try await WiFiService.shared.connect(to: credentials)
                await MainActor.run {
                    isConnecting = false
                    // Replace the connecting toast with success toast
                    showToast(.success(message: "Successfully connected to \(credentials.ssid)", icon: "wifi"))
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    // Clear the connecting toast when showing the error alert
                    withAnimation {
                        activeToast = nil
                    }
                    connectionError = error
                    showingConnectionError = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContentViewModel())
}
