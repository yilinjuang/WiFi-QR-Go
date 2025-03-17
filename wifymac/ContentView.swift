//
//  ContentView.swift
//  wifymac
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
    @State private var connectionSuccess = false
    @State private var passwordCopied = false

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

                    // QR code capture overlay
                    QRCodeCaptureOverlay()
                }
                .padding()

                if isConnecting {
                    ProgressView("Connecting to Wi-Fi...")
                        .padding()
                        .font(.title3)
                } else if connectionSuccess {
                    Text("Successfully connected to \(viewModel.wifiCredentials?.ssid ?? "Wi-Fi")")
                        .foregroundColor(.green)
                        .font(.title3)
                        .padding()
                } else if passwordCopied {
                    Text("Password copied to clipboard")
                        .foregroundColor(.blue)
                        .font(.title3)
                        .padding()
                        .onAppear {
                            // Reset the copied state after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                passwordCopied = false
                            }
                        }
                }
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
        .alert("Wi-Fi Network Found", isPresented: $viewModel.showingCredentialsAlert) {
            Button("Connect", role: .none) {
                connectToWiFi()
            }
            Button("Copy Password", role: .none) {
                if let password = viewModel.wifiCredentials?.password {
                    ClipboardHelper.copyToClipboard(password)
                    passwordCopied = true
                }
            }
            .disabled(viewModel.wifiCredentials?.password == nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            if let credentials = viewModel.wifiCredentials {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Would you like to connect to \(credentials.ssid)?")
                    if let password = credentials.password {
                        Text("Password: \(password)")
                            .font(.caption)
                    }
                }
            }
        }
        .alert("Connection Error", isPresented: $showingConnectionError) {
            Button("Copy Password", role: .none) {
                if let password = viewModel.wifiCredentials?.password {
                    ClipboardHelper.copyToClipboard(password)
                    passwordCopied = true
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

    private func connectToWiFi() {
        guard let credentials = viewModel.wifiCredentials else { return }

        isConnecting = true

        Task {
            do {
                try await WiFiService.shared.connect(to: credentials)
                await MainActor.run {
                    isConnecting = false
                    connectionSuccess = true
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
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
