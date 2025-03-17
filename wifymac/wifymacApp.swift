//
//  WifyApp.swift
//  wifymac
//
//  Created by Yi-Lin Juang on 2025/3/17.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Center the window when the app launches
        if let window = NSApplication.shared.windows.first {
            // Get the screen frame
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero

            // Calculate the centered position
            let x = screenFrame.origin.x + (screenFrame.width - window.frame.width) / 2
            let y = screenFrame.origin.y + (screenFrame.height - window.frame.height) / 2

            // Set the window position
            window.setFrameOrigin(NSPoint(x: x, y: y))
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct WifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var contentViewModel = ContentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                }
                .environmentObject(contentViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commandsRemoved()
        .commands {
            // App menu - About Wify
            CommandGroup(replacing: .appInfo) {
                Button("About Wify") {
                    let options: [NSApplication.AboutPanelOptionKey: Any] = [
                        .credits: NSAttributedString(
                            string: "Quickly connect to WiFi by scanning QR code",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        ),
                    ]

                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }

            // App menu - Quit
            CommandGroup(replacing: .appTermination) {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }

            // File menu - Import QR code
            CommandGroup(replacing: .importExport) {
                Button("Import QR code") {
                    importQRCodeFromFile()
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }
    }

    func importQRCodeFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [UTType.image]

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                // Use the QRCodeProcessingService to process the image
                QRCodeProcessingService.shared.processQRCodeImage(url) { credentials in
                    if let credentials = credentials {
                        DispatchQueue.main.async {
                            self.contentViewModel.wifiCredentials = credentials
                            self.contentViewModel.showingCredentialsAlert = true
                        }
                    } else {
                        // Show an alert if no valid QR code was found
                        let alert = NSAlert()
                        alert.messageText = "No Wi-Fi QR Code Found"
                        alert.informativeText = "The selected image does not contain a valid Wi-Fi QR code."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
}

// Shared view model to communicate between app and ContentView
class ContentViewModel: ObservableObject {
    @Published var wifiCredentials: WiFiCredentials?
    @Published var showingCredentialsAlert = false
}
