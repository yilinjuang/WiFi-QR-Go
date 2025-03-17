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
    @State private var wifiCredentials: WiFiCredentials?
    @State private var showingCredentialsAlert = false
    @State private var isConnecting = false
    @State private var connectionError: Error?
    @State private var showingConnectionError = false
    @State private var connectionSuccess = false
    @State private var showingManualConnection = false

    var body: some View {
        VStack {
            if cameraManager.isAuthorized {
                ZStack {
                    // Camera preview
                    CameraPreviewView(previewLayer: cameraManager.getPreviewLayer())
                        .frame(minWidth: 400, minHeight: 300)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray, lineWidth: 1)
                        )

                    // QR code scanning overlay
                    VStack {
                        Spacer()
                        Text("Scan a Wi-Fi QR Code")
                            .font(.headline)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.bottom, 20)
                    }
                }
                .padding()

                if isConnecting {
                    ProgressView("Connecting to Wi-Fi...")
                        .padding()
                } else if connectionSuccess {
                    Text("Successfully connected to \(wifiCredentials?.ssid ?? "Wi-Fi")")
                        .foregroundColor(.green)
                        .padding()
                } else if showingManualConnection, let credentials = wifiCredentials {
                    ManualConnectionView(credentials: credentials)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("Camera access is required")
                        .font(.headline)

                    Text("Please allow camera access in System Settings")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 500, height: 400)
        .onChange(of: cameraManager.qrCodeContent) { oldValue, newValue in
            if let content = newValue, let credentials = WiFiCredentials.parse(from: content) {
                wifiCredentials = credentials
                showingCredentialsAlert = true
                // Reset QR code content to allow scanning again
                cameraManager.qrCodeContent = nil
            }
        }
        .alert("Wi-Fi Network Found", isPresented: $showingCredentialsAlert) {
            Button("Connect", role: .none) {
                connectToWiFi()
            }
            Button("Manual Connection", role: .none) {
                showingManualConnection = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let credentials = wifiCredentials {
                Text("Would you like to connect to \(credentials.ssid)?")
            }
        }
        .alert("Connection Error", isPresented: $showingConnectionError) {
            Button("Manual Connection", role: .none) {
                showingManualConnection = true
            }
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
        guard let credentials = wifiCredentials else { return }

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
}
